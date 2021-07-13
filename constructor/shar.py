# (c) 2016 Anaconda, Inc. / https://anaconda.com
# All Rights Reserved
#
# constructor is distributed under the terms of the BSD 3-clause license.
# Consult LICENSE.txt or http://opensource.org/licenses/BSD-3-Clause.

from __future__ import absolute_import, division, print_function

import os
from os.path import basename, dirname, getsize, isdir, join
import shutil
import stat
import tarfile
import tempfile

from .construct import ns_platform
from .preconda import files as preconda_files, write_files as preconda_write_files
from .utils import add_condarc, filename_dist, fill_template, md5_files, preprocess, \
    read_ascii_only, get_final_channels

THIS_DIR = dirname(__file__)


def has_shebang(filename):
    with open(filename, "rb") as fp:
        return b"#!" == fp.read(2)


def make_executable(tarinfo):
    tarinfo.mode |= stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
    return tarinfo


def read_header_template():
    path = join(THIS_DIR, 'header.sh')
    print('Reading: %s' % path)
    with open(path) as fi:
        return fi.read()


def get_header(conda_exec, tarball, info):
    name = info['name']

    has_license = bool('license_file' in info)
    ppd = ns_platform(info['_platform'])
    ppd['keep_pkgs'] = bool(info.get('keep_pkgs', False))
    ppd['batch_mode'] = bool(info.get('batch_mode', False))
    ppd['has_license'] = has_license
    if ppd['batch_mode'] and has_license:
        raise Exception(
            "It is not possible to use both the 'batch_mode' and "
            "'license_file' options together."
        )
    for key in 'pre_install', 'post_install', 'pre_uninstall':
        ppd['has_%s' % key] = bool(key in info)
        if key in info:
            ppd['direct_execute_%s' % key] = has_shebang(info[key])
    ppd['initialize_by_default'] = info.get('initialize_by_default', None)
    ppd['has_conda'] = info['_has_conda']
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
        'FIRST_PAYLOAD_SIZE': str(getsize(conda_exec)),
        'SECOND_PAYLOAD_SIZE': str(getsize(tarball)),
        'INSTALL_COMMANDS': '\n'.join(install_lines),
        'CHANNELS': ','.join(get_final_channels(info)),
        'pycache': '__pycache__',
    }
    if has_license:
        replace['LICENSE'] = read_ascii_only(info['license_file'])

    data = read_header_template()
    data = preprocess(data, ppd)
    data = fill_template(data, replace)

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
    tmp_dir_base_path = join(dirname(info['_outpath']), "tmp")
    try:
        os.makedirs(tmp_dir_base_path)
    except Exception:
        pass
    tmp_dir = tempfile.mkdtemp(dir=tmp_dir_base_path)
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
            pre_t.add(info[key], 'pkgs/%s.sh' % key,
                      filter=make_executable if has_shebang(info[key]) else None)
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
