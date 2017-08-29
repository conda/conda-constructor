# (c) 2016 Continuum Analytics, Inc. / http://continuum.io
# All Rights Reserved
#
# constructor is distributed under the terms of the BSD 3-clause license.
# Consult LICENSE.txt or http://opensource.org/licenses/BSD-3-Clause.

from __future__ import print_function, division, absolute_import

import os
import shutil
import tarfile
import tempfile
from os.path import dirname, getsize, join

from constructor.install import name_dist
from constructor.construct import ns_platform
from constructor.utils import (preprocess, read_ascii_only, fill_template,
                               md5_file)
import constructor.preconda as preconda


THIS_DIR = dirname(__file__)


def read_header_template():
    path = join(THIS_DIR, 'header.sh')
    print('Reading: %s' % path)
    with open(path) as fi:
        return fi.read()


def add_condarc(info):
    channels = info.get('conda_default_channels')
    if channels:
        yield '# ----- add condarc'
        yield 'cat <<EOF >$PREFIX/.condarc'
        yield 'default_channels:'
        for url in channels:
            yield '  - %s' % url
        yield 'EOF'


def get_header(tarball, info):
    name = info['name']
    dists = [fn[:-8] for fn in info['_dists']]
    dist0 = dists[0]
    assert name_dist(dist0) == 'python'

    has_readme = bool('readme_file' in info)
    has_license = bool('license_file' in info)
    ppd = ns_platform(info['_platform'])
    ppd['keep_pkgs'] = bool(info.get('keep_pkgs'))
    ppd['has_readme'] = has_readme
    ppd['has_license'] = has_license
    for key in 'pre_install', 'post_install':
        ppd['has_%s' % key] = bool(key in info)
    ppd['add_to_path_default'] = info.get('add_to_path_default', None)

    install_lines = ['install_dist %s' % d for d in dists]
    install_lines.extend(add_condarc(info))
    # Needs to happen first -- can be templated
    replace = {
        'NAME': name,
        'name': name.lower(),
        'VERSION': info['version'],
        'PLAT': info['_platform'],
        'DIST0': dist0,
        'DEFAULT_PREFIX': info.get('default_prefix',
                                   '$HOME/%s' % name.lower()),
        'MD5': md5_file(tarball),
        'INSTALL_COMMANDS': '\n'.join(install_lines),
        'pycache': '__pycache__',
    }
    if has_readme:
        replace['README'] = read_ascii_only(info['readme_file'])
    if has_license:
        replace['LICENSE'] = read_ascii_only(info['license_file'])

    data = read_header_template()
    data = preprocess(data, ppd)
    data = fill_template(data, replace)
    n = data.count('\n')
    data = data.replace('@LINES@', str(n + 1))

    # note that this replacement does not change the size of the header,
    # which would result into an inconsistency
    n = len(data) + getsize(tarball)
    data = data.replace('@SIZE_BYTES@', '%12d' % n)
    assert len(data) + getsize(tarball) == n

    return data


def create(info):
    tmp_dir = tempfile.mkdtemp()
    preconda.write_files(info, tmp_dir)
    tarball = join(tmp_dir, 'tmp.tar')
    t = tarfile.open(tarball, 'w')
    if 'readme_file' in info:
        t.add(info['readme_file'], 'README.txt')
    if 'license_file' in info:
        t.add(info['license_file'], 'LICENSE.txt')
    for fn in preconda.files:
        t.add(join(tmp_dir, fn), 'pkgs/' + fn)
    for fn in info['_dists']:
        t.add(join(info['_download_dir'], fn), 'pkgs/' + fn)
    for key in 'pre_install', 'post_install':
        if key in info:
            t.add(info[key], 'pkgs/%s.sh' % key)
    t.close()

    header = get_header(tarball, info)
    shar_path = info['_outpath']
    with open(shar_path, 'wb') as fo:
        fo.write(header.encode('utf-8'))
        with open(tarball, 'rb') as fi:
            while True:
                chunk = fi.read(262144)
                if not chunk:
                    break
                fo.write(chunk)

    os.unlink(tarball)
    os.chmod(shar_path, 0o755)
    shutil.rmtree(tmp_dir)
