# (c) 2016 Anaconda, Inc. / https://anaconda.com
# All Rights Reserved
#
# constructor is distributed under the terms of the BSD 3-clause license.
# Consult LICENSE.txt or http://opensource.org/licenses/BSD-3-Clause.

from __future__ import absolute_import, division, print_function

import os
from os.path import basename, dirname, getsize, isdir, join
import json
import shutil
import tarfile
import tempfile

from .construct import ns_platform
from .install import name_dist
from .preconda import files as preconda_files, write_files as preconda_write_files
from .utils import add_condarc, filename_dist, fill_template, md5_files, preprocess, read_ascii_only, get_final_channels

THIS_DIR = dirname(__file__)


def read_header_template():
    path = join(THIS_DIR, 'header.sh')
    print('Reading: %s' % path)
    with open(path) as fi:
        return fi.read()


def get_header(conda_exec, tarball, info):
    name = info['name']

    has_license = bool('license_file' in info)
    ppd = ns_platform(info['_platform'])
    ppd['keep_pkgs'] = bool(info.get('keep_pkgs'))
    ppd['attempt_hardlinks'] = bool(info.get('attempt_hardlinks'))
    ppd['has_license'] = has_license
    for key in 'pre_install', 'post_install':
        ppd['has_%s' % key] = bool(key in info)
    ppd['initialize_by_default'] = info.get('initialize_by_default', None)
    install_lines = list(add_condarc(info))
    # Needs to happen first -- can be templated
    replace = {
        'NAME': name,
        'name': name.lower(),
        'VERSION': info['version'],
        'PLAT': info['_platform'],
        'DEFAULT_PREFIX': info.get('default_prefix',
                                   '$HOME/%s' % name.lower()),
        'MD5': md5_files([conda_exec, tarball]),
        'INSTALL_COMMANDS': '\n'.join(install_lines),
        'pycache': '__pycache__',
    }
    if has_license:
        replace['LICENSE'] = read_ascii_only(info['license_file'])

    data = read_header_template()
    data = preprocess(data, ppd)
    data = fill_template(data, replace)
    n = data.count('\n')
    data = data.replace('@LINES@', str(n + 1))
    data = data.replace('@CHANNELS@', ','.join(get_final_channels(info)))

    # Make all replacements before this
    # zero padding is to ensure size of header doesn't change depending on
    #    size of packages included.  The actual space you have is the number
    #    of characters in the string here - @NON_PAYLOAD_SIZE@ is 18 chars
    data = data.replace('@FIRST_PAYLOAD_SIZE@', '%020d' % getsize(conda_exec))
    data = data.replace('@NON_PAYLOAD_SIZE@', '%018d' % len(data))
    payload_offset = len(data) + getsize(conda_exec)
    n = payload_offset + getsize(tarball)
    # this one is not zero-padded because it is used in a different way, and is compared
    #    with the actual size at install time (which is not zero padded)
    data = data.replace('@TOTAL_SIZE_BYTES@', str(n))
    data = data.replace('@PAYLOAD_OFFSET_BYTES@', '%022d' % payload_offset)
    data = data.replace('@TARBALL_SIZE_BYTES@', '%020d' % getsize(tarball))
    assert len(data) + getsize(conda_exec) + getsize(tarball) == n

    return data

def add_repodata(fn_dict, subdir):
    """This is used to write local repodata.  Local packages are considered to live
    in $PREFIX/conda-bld on the destination system."""
    with open('repodata.json', 'w') as f:
        json.dump({
            "info": {
                "subdir": subdir
            },
            "packages": fn_dict['packages'],
            "packages.conda": fn_dict['packages.conda'],
            "removed": [],
            "repodata_version": 1
        }, f)
    t.add('repodata.json', '/'.join(('conda-bld', subdir, 'repodata.json')))


def create(info, verbose=False):
    tmp_dir = tempfile.mkdtemp()
    preconda_write_files(info, tmp_dir)

    preconda_tarball = join(tmp_dir, 'preconda.tar.bz2')
    postconda_tarball = join(tmp_dir, 'postconda.tar.bz2')
    pre_t = tarfile.open(preconda_tarball, 'w:bz2')
    post_t = tarfile.open(postconda_tarball, 'w:bz2')
    for dist in preconda_files:
        fn = filename_dist(dist)
        pre_t.add(join(tmp_dir, fn), 'pkgs/' + fn)
    for key in 'pre_install', 'post_install':
        if key in info:
            pre_t.add(info[key], 'pkgs/%s.sh' % key)
    cache_dir = join(tmp_dir, 'cache')
    if isdir(cache_dir):
        for cf in os.listdir(cache_dir):
            if cf.endswith(".json"):
                pre_t.add(join(cache_dir, cf), 'pkgs/cache/' + cf)
    for dist in info['_dists']:
        if filename_dist(dist).endswith(".conda"):
            _dist = filename_dist(dist)[:-6]
        elif filename_dist(dist).endswith(".tar.bz2"):
            _dist = filename_dist(dist)[:-8]
        record_file = join(_dist, 'info', 'repodata_record.json')
        record_file_src = join(tmp_dir, record_file)
        record_file_dest = join('pkgs', record_file)
        pre_t.add(record_file_src, record_file_dest)
    pre_t.addfile(tarinfo=tarfile.TarInfo("conda-meta/history"))
    post_t.add(join(tmp_dir, 'conda-meta', 'history'), 'conda-meta/history')
    pre_t.close()
    post_t.close()

    tarball = join(tmp_dir, 'tmp.tar')
    t = tarfile.open(tarball, 'w')
    t.add(preconda_tarball, basename(preconda_tarball))
    t.add(postconda_tarball, basename(postconda_tarball))
    if 'license_file' in info:
        t.add(info['license_file'], 'LICENSE.txt')
    for dist in info['_dists']:
        fn = filename_dist(dist)
        t.add(join(info['_download_dir'], fn), 'pkgs/' + fn)

    local_subdir_repodata = {}
    for url, _ in info['_urls']:
        if url.startswith('file://'):
            _, subdir, fn = url.rsplit('/', 2)
            t.add(join(info['_download_dir'], fn), '/'.join(('conda-bld', subdir, fn)))
            # load the repodata from JSON and build up the new local repodata from individual entries
            with open(url.replace('file://', '').replace(fn, 'repodata.json')) as f:
                repodata = json.load(f)
                local_dir = local_subdir_repodata.get(subdir, {
                    'packages': {},
                    'packages.conda': {},
                })
                if fn.endswith('.conda'):
                    local_dir['packages.conda'][fn] = repodata['packages.conda'][fn]
                else:
                    local_dir['packages'][fn] = repodata['packages'][fn]
                local_subdir_repodata[subdir] = local_dir

    has_noarch = False
    for subdir, fn_dict in local_subdir_repodata.items():
        if not has_noarch and subdir == 'noarch':
            has_noarch = True
        add_repodata(fn_dict, subdir)
    if not has_noarch:
        add_repodata({'packages': {}, 'packages.conda': {}}, 'noarch')
    t.close()

    conda_exec = info["_conda_exe"]
    header = get_header(conda_exec, tarball, info)
    shar_path = info['_outpath']
    with open(shar_path, 'wb') as fo:
        fo.write(header.encode('utf-8'))
        for payload in [conda_exec, tarball]:
            with open(payload, 'rb') as fi:
                while True:
                    chunk = fi.read(262144)
                    if not chunk:
                        break
                    fo.write(chunk)

    os.unlink(tarball)
    os.chmod(shar_path, 0o755)
    shutil.rmtree(tmp_dir)
