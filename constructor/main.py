# (c) 2016 Anaconda, Inc. / https://anaconda.com
# All Rights Reserved
#
# constructor is distributed under the terms of the BSD 3-clause license.
# Consult LICENSE.txt or http://opensource.org/licenses/BSD-3-Clause.

from __future__ import absolute_import, division, print_function

import os
from os.path import abspath, basename, expanduser, isdir, isfile, join
import sys

from .conda_interface import cc_platform
from .construct import (parse as construct_parse,
                        verify as construct_verify,
                        split as construct_split)
from .fcp import main as fcp_main
from .install import yield_lines
from .utils import normalize_path

from . import __version__

DEFAULT_CACHE_DIR = os.getenv('CONSTRUCTOR_CACHE', '~/.conda/constructor')


def set_installer_type(info):
    osname, unused_arch = info['_platform'].split('-')

    if not info.get('installer_type'):
        os_map = {'linux': 'sh', 'osx': 'sh', 'win': 'exe'}
        info['installer_type'] = os_map[osname]

    allowed_types = 'sh', 'pkg', 'exe'
    itype = info['installer_type']
    if itype not in allowed_types:
        sys.exit("Error: invalid installer type '%s',\n"
                 "allowed types are: %s" % (itype, allowed_types))

    if ((osname == 'linux' and itype != 'sh') or
        (osname == 'osx' and itype not in ('sh', 'pkg')) or
        (osname == 'win' and itype != 'exe')):
        sys.exit("Error: cannot create '.%s' installer for %s" % (itype,
                                                                  osname))


def get_output_filename(info):
    try:
        return info['installer_filename']
    except KeyError:
        pass

    osname, arch = info['_platform'].split('-')
    os_map = {'linux': 'Linux', 'osx': 'MacOSX', 'win': 'Windows'}
    arch_name_map = {'64': 'x86_64', '32': 'x86'}
    ext = info['installer_type']
    return '%s-%s-%s.%s' % ('%(name)s-%(version)s' % info,
                            os_map.get(osname, osname),
                            arch_name_map.get(arch, arch),
                            ext)


def main_build(dir_path, output_dir='.', platform=cc_platform,
               verbose=True, cache_dir=DEFAULT_CACHE_DIR,
               dry_run=False, conda_exe="conda.exe"):
    print('platform: %s' % platform)
    if not os.path.isfile(conda_exe):
        sys.exit("Error: Conda executable '%s' does not exist!" % conda_exe)
    cache_dir = abspath(expanduser(cache_dir))
    try:
        osname, unused_arch = platform.split('-')
    except ValueError:
        sys.exit("Error: invalid platform string '%s'" % platform)

    construct_path = join(dir_path, 'construct.yaml')
    info = construct_parse(construct_path, platform)
    construct_verify(info)
    info['_platform'] = platform
    info['_download_dir'] = join(cache_dir, platform)
    info['_conda_exe'] = abspath(conda_exe)
    for info in construct_split(info):
        build_single(info, dir_path, output_dir, verbose, dry_run, conda_exe)


def build_single(info, dir_path, output_dir, verbose, dry_run, conda_exe):
    set_installer_type(info)

    if info['installer_type'] == 'sh':
        if sys.platform == 'win32':
            sys.exit("Error: Cannot create .sh installer on Windows.")
        from .shar import create
    elif info['installer_type'] == 'pkg':
        if sys.platform != 'darwin':
            sys.exit("Error: Can only create .pkg installer on OSX.")
        from .osxpkg import create
    elif info['installer_type'] == 'exe':
        if sys.platform != 'win32':
            sys.exit("Error: Can only create .pkg installer on Windows.")
        from .winexe import create

    if verbose:
        print('conda packages download: %s' % info['_download_dir'])

    for key in ('welcome_image_text', 'header_image_text'):
        if key not in info:
            info[key] = info['name']

    for key in ('license_file', 'welcome_image', 'header_image', 'icon_image',
                'pre_install', 'post_install', 'pre_uninstall', 'environment_file'):
        if key in info:
            info[key] = abspath(join(dir_path, info[key]))

    for key in 'specs', 'packages':
        if key not in info:
            continue
        if isinstance(info[key], str):
            info[key] = list(yield_lines(join(dir_path, info[key])))

    for key in 'channels', 'specs', 'exclude', 'packages', 'menu_packages':
        if key in info:
            # ensure strings in those lists are stripped
            info[key] = [line.strip() for line in info[key]]
            # ensure there are no empty strings
            if any((not s) for s in info[key]):
                sys.exit("Error: found empty element in '%s:'" % key)

    fcp_main(info, verbose=verbose, dry_run=dry_run, conda_exe=conda_exe)
    if dry_run:
        print("Dry run, no installer created.")
        return

    info['_outpath'] = abspath(join(output_dir, get_output_filename(info)))

    # info has keys
    # 'name', 'version', 'channels', 'exclude',
    # '_platform', '_download_dir', '_outpath'
    # 'specs': ['python 3.5*', 'conda', 'nomkl', 'numpy', 'scipy', 'pandas', 'notebook', 'matplotlib', 'lighttpd']
    # 'license_file': '/Users/kfranz/continuum/constructor/examples/maxiconda/EULA.txt'
    # '_dists': List[Dist]
    # '_urls': List[Tuple[url, md5]]

    create(info, verbose=verbose)
    if 0:
        with open(join(output_dir, 'pkg-list.txt'), 'w') as fo:
            fo.write('# installer: %s\n' % basename(info['_outpath']))
            for dist in info['_dists']:
                fo.write('%s\n' % dist)
    print("Successfully created '%(_outpath)s'." % info)


def main():
    import argparse

    p = argparse.ArgumentParser(
        description="build an installer from <DIRECTORY>/construct.yaml")

    p.add_argument('--debug',
                 action="store_true")

    p.add_argument('--output-dir',
                 action="store",
                 default=os.getcwd(),
                 help='path to directory in which output installer is written '
                      "to, defaults to CWD ('{}')".format(os.getcwd()),
                 metavar='PATH')

    p.add_argument('--cache-dir',
                 action="store",
                 default=DEFAULT_CACHE_DIR,
                 help='cache directory, used for downloading conda packages, '
                      'may be changed by CONSTRUCTOR_CACHE, '
                      "defaults to '{}'".format(DEFAULT_CACHE_DIR),
                 metavar='PATH')

    p.add_argument('--clean',
                 action="store_true",
                 help='clean out the cache directory and exit')

    p.add_argument('--platform',
                 action="store",
                 default=cc_platform,
                 help="the platform for which installer is for, "
                      "defaults to '{}'".format(cc_platform))

    p.add_argument('--dry-run',
                 help="solve package specs but do not create installer",
                 default=False,
                 action="store_true")

    p.add_argument('-v', '--verbose',
                 action="store_true")

    p.add_argument('-V', '--version',
                 help="display the version being used and exit",
                 action="version",
                 version='%(prog)s {version}'.format(version=__version__))

    p.add_argument('--conda-exe',
                 help="path to conda executable",
                 action="store",
                 metavar="CONDA_EXE")

    p.add_argument('dir_path',
                   help="directory containing construct.yaml",
                   action="store",
                   nargs="?",
                   default=os.getcwd(),
                   metavar='DIRECTORY')

    args = p.parse_args()

    if args.clean:
        import shutil
        cache_dir = abspath(expanduser(args.cache_dir))
        print("cleaning cache: '%s'" % cache_dir)
        if isdir(cache_dir):
            shutil.rmtree(cache_dir)
        return

    if args.debug:
        import logging
        logging.basicConfig(level=logging.DEBUG)

    dir_path = args.dir_path
    if not isdir(dir_path):
        p.error("no such directory: %s" % dir_path)

    if not args.conda_exe:
        # try a default name of conda.exe in constructor's installed location
        conda_exe_default_path = os.path.join(sys.prefix, "standalone_conda", "conda.exe")
        if os.path.isfile(conda_exe_default_path):
            args.conda_exe = conda_exe_default_path
        else:
            raise ValueError("You must supply a path to self-contained conda executable with the "
                             "--conda-exe parameter.  You may prefer to download one for your OS "
                             "and place it in the root of your prefix, named 'conda.exe' to save "
                             "yourself some typing.  Self-contained conda executables can be "
                             "downloaded from https://repo.anaconda.com/pkgs/misc/conda-execs/")

    out_dir = normalize_path(args.output_dir)
    main_build(dir_path, output_dir=out_dir, platform=args.platform,
               verbose=args.verbose, cache_dir=args.cache_dir,
               dry_run=args.dry_run, conda_exe=args.conda_exe)


if __name__ == '__main__':
    main()
