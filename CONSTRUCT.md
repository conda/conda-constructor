
# The `construct.yaml` specification

The `construct.yaml` file is the primary mechanism for controlling
the output of the Constructor package. The file contains a list of
key/value pairs in the standard [YAML](https://yaml.org/) format.
Each configuration option is listed in its own subsection below.

Constructor employs the Selector enhancement of the YAML format
first employed in the
[conda-build](https://docs.conda.io/projects/conda-build/en/latest/)
project. Selectors are specially formatted YAML comments that Constructor
uses to customize the specification for different platforms. The precise
syntax for selectors is described in
[this section](https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html#preprocessing-selectors)
of the `conda-build` documentation. The list of selectors available
for use in Constructor specs is given in the section
[Available selectors](#Available-selectors) below.


## `name`

_required:_ yes<br/>
_type:_ string<br/>
Name of the installer. Names may be composed of letters, numbers,
underscores, dashes, and periods, but may not begin or end with a
dash or period.

## `version`

_required:_ yes<br/>
_type:_ string<br/>
Version of the installer. Versions may be composed of letters, numbers,
underscores, dashes, and periods, but may not begin or end with a
dash or period.

## `channels`

_required:_ no<br/>
_type:_ list<br/>
The conda channels from which packages are retrieved.

## `channels_remap`

_required:_ no<br/>
_type:_ list<br/>
A list of `src/dest` channel pairs. When retrieving the packages, conda will
use the `src` channels; but rename those channels to `dst` within the installer.
This allows an installer to be built against a different set of channels than
will be present when the installer is actually used. Example use:
```
channels_remap:
  -
      src: file:///tmp/a3/conda-bld
      dest: https://repo.anaconda.com/pkgs/main
  -
      src: file:///tmp/r/conda-bld
      dest: https://repo.anaconda.com/pkgs/r
```

## `specs`

_required:_ no<br/>
_types:_ list, string<br/>
A list of package specifications; e.g. `python 2.7*`, `pyzmq` or `numpy >=1.8`.
The specifications are identical in form and purpose to those that would be
included in a `conda create --file` command. Packages may also be specified
by an exact URL; e.g.,
`https://repo.anaconda.com/pkgs/main/osx-64/openssl-1.0.2o-h26aff7b_0.tar.bz2`.

## `user_requested_specs`

_required:_ no<br/>
_types:_ list, string<br/>
A list of package specifications to be recorded as "user-requested" for the
initial environment in conda's history file. This information is used by newer
versions of conda to better filter its package choices on subsequent installs;
for example, if `python=3.6` is included, then conda will always seek versions
of packages compatible with Python 3.6. If this is option is not provided, it
will be set equal to the value of `specs`.

## `exclude`

_required:_ no<br/>
_type:_ list<br/>
A list of package names to be excluded after the `specs` have been resolved.
For example, you can say that `readline` should be excluded, even though it
is contained as a result of resolving the specs for `python 2.7`.

## `menu_packages`

_required:_ no<br/>
_type:_ list<br/>
A list of packages with menu items to be instsalled. The packages must have
necessary metadata in "Menu/<package name>.json").  Menu items are currently
only supported on Windows. By default, all menu items will be installed;
supplying this list allows a subset to be selected instead.

## `ignore_duplicate_files`

_required:_ no<br/>
_type:_ boolean<br/>
By default, constructor will error out when adding packages with duplicate
files in them. Enable this option to warn instead and continue.

## `install_in_dependency_order`

_required:_ no<br/>
_type:_ boolean<br/>
By default, the conda packages included in the created installer are installed
in alphabetical order, with the exception of Python itself, which is installed
first. Using this option, packages are installed in dependency order.

## `environment`

_required:_ no<br/>
_type:_ string<br/>
Name of the environment to construct from. If this option is present, the
`specs` argument will be ignored. Using this option allows the user to
curate the enviromment interactively using standard `conda` commands, and
run constructor with full confidence that the exact environment will be
reproduced.

## `environment_file`

_required:_ no<br/>
_type:_ string<br/>
Path to an environment file to construct from. If this option is present, the
`specs` argument will be ignored. Instead, constructor will call conda to
create a temporary environment, constructor will build and installer from
that, and the temporary environment will be removed. This ensures that
constructor is using the precise local conda configuration to discover
and install the packages.

## `conda_default_channels`

_required:_ no<br/>
_type:_ list<br/>
If this value is provided as well as `write_condarc`, then the channels
in this list will be included as the value of the `default_channels:`
option in the environment's `.condarc` file. This will have an impact
only if `conda` is included in the environmnent.

## `conda_channel_alias`

_required:_ no<br/>
_type:_ string<br/>
The channel alias that would be assumed for the created installer
(only useful if it includes conda).

## `installer_filename`

_required:_ no<br/>
_type:_ string<br/>
The filename of the installer being created. If not supplied, a reasonable
default will determined by the `name`, `version`, platform, and installer type.

## `installer_type`

_required:_ no<br/>
_type:_ string<br/>
The type of the installer being created.  Possible values are "sh", "pkg",
and "exe". The default type is "sh" on Unix, and "exe" on Windows.

## `license_file`

_required:_ no<br/>
_type:_ string<br/>
Path to the license file being displayed by the installer during the install
process.

## `keep_pkgs`

_required:_ no<br/>
_type:_ boolean<br/>
If `False` (default), the package cache in the `pkgs` subdirectory is removed
when the installation process is complete. If `True`, this subdirectory and
its contents are preserved. If `keep_pkgs` is `False`, Unix `.sh` and Windows `.msi`
installers offer a command-line option (`-k` and `/KeepPkgCache`, respectively)
to preserve the package cache.

## `signing_identity_name`

_required:_ no<br/>
_type:_ string<br/>
By default, the MacOS pkg installer isn't signed. If an identity name is specified
using this option, it will be used to sign the installer. Note that you will need
to have a certificate and corresponding private key together called an 'identity'
in one of your accessible keychains.

## `attempt_hardlinks`

_required:_ no<br/>
_type:_ boolean<br/>
By default, conda packages are extracted into the root environment and then
patched. Enabling this option will result into extraction of the packages into
the `pkgs` directory and the files in the root environment will be hardlinks to
the files kept in the `pkgs` directory and then patched accordingly.

## `write_condarc`

_required:_ no<br/>
_type:_ boolean<br/>
By default, no `.condarc` file is written. If set, a `.condarc` file is written to
the base environment if there are any channels or conda_default_channels is set.

## `condarc`

_required:_ no<br/>
_types:_ dictionary, string<br/>
If set, a `.condarc` file is written to the base environment containing the contents
of this value. The value can either be a string (likely a multi-line string) or
a dictionary, which will be converted to a YAML string for writing. _Note:_ if this
option is used, then all other options related to the construction of a `.condarc`
file&mdash;`write_condarc`, `conda_default_channels`, etc.&mdash;are ignored.

## `company`

_required:_ no<br/>
_type:_ string<br/>
Name of the company/entity who is responsible for the installer.

## `uninstall_name`

_required:_ no<br/>
_type:_ string<br/>
Application name in the Windows "Programs and Features" control panel.
Defaults to `${NAME} ${VERSION} (Python ${PYVERSION} ${ARCH})`.

## `pre_install`

_required:_ no<br/>
_type:_ string<br/>
Path to a pre install script. This is available for Unix only, and
must be a Bash script.

## `post_install`

_required:_ no<br/>
_type:_ string<br/>
Path to a post install script. This must be a Bash script for Unix
and a `.bat` file for Windows.

## `post_install_desc`

_required:_ no<br/>
_type:_ string<br/>
A description of the purpose of the supplied post_install script. If this
string is supplied and non-empty, then the Windows and macOS GUI installers
will display it along with checkbox to enable or disable the execution of the
script. If this string is not supplied, it is assumed that the script
is compulsory and the option to disable it will not be offered.

## `pre_uninstall`

_required:_ no<br/>
_type:_ string<br/>
Path to a pre uninstall script. This is only supported for on Windows,
and must be a `.bat` file.

## `welcome_image`

_required:_ no<br/>
_type:_ string<br/>
Path to an image in any common image format (`.png`, `.jpg`, `.tif`, etc.)
to be used as the welcome image for the Windows installer.
The image is re-sized to 164 x 314 pixels.
By default, an image is automatically generated.

## `header_image`

_required:_ no<br/>
_type:_ string<br/>
Like `welcome_image` for Windows, re-sized to 150 x 57 pixels.

## `icon_image`

_required:_ no<br/>
_type:_ string<br/>
Like `welcome_image` for Windows, re-sized to 256 x 256 pixels.

## `default_image_color`

_required:_ no<br/>
_type:_ string<br/>
The color of the default images (when not providing explicit image files)
used on Windows.  Possible values are `red`, `green`, `blue`, `yellow`.
The default is `blue`.

## `welcome_image_text`

_required:_ no<br/>
_type:_ string<br/>
If `welcome_image` is not provided, use this text when generating the image
(Windows only). Defaults to `name`.

## `header_image_text`

_required:_ no<br/>
_type:_ string<br/>
If `header_image` is not provided, use this text when generating the image
(Windows only). Defaults to `name`.

## `initialize_by_default`

_required:_ no<br/>
_type:_ boolean<br/>
Whether to add the installation to the PATH environment variable. The default
is true for GUI installers (msi, pkg) and False for shell installers. The user
is able to change the default during interactive installation.

## `register_python_default`

_required:_ no<br/>
_type:_ boolean<br/>
Default choice for whether to register the installed Python instance as the
system's default Python. The user is still able to change this during
interactive installation. (Windows only)

## `installers`

_required:_ no<br/>
_type:_ dictionary<br/>
When supplied, `installers` is a dictionary of dictionaries that allows a single
`construct.yaml` file to describe multiple installers. In this mode, the top-level
options provide a set of "parent" specifications which are merged which each
child dictionary in a simple fashion to yield a complete installer specification.
The merging approach is as follows:
- For _string_ options, the "parent" spec provides a simple default. If a
  child spec includes the same key, its value overrides the parent.
- For _list_ options, the "parent" and "child" lists are _concatenated_ for the
  final spec. This allows, for instance, the parent to specify a set of
  base packages to include in all installers.
- For _dictionary_ options, the "parent" and "child" dictionaries are combined,
  with any intersecting keys resolved in favor of the child.

In this mode, the name of each installer is given by the dictionary keys in the
`installers` option, and the `name` field must not be explicitly supplied.

## `check_path_length`

_required:_ no<br/>
_type:_ boolean<br/>
Check the length of the path where the distribution is installed to ensure nodejs
can be installed.  Raise a message to request shorter path (less than 46 character)
or enable long path on windows > 10 (require admin right). Default is True. (Windows only)


## Available selectors

- `aarch64`
- `arm64`
- `armv7l`
- `linux`
- `linux32`
- `linux64`
- `osx`
- `ppc64le`
- `s390x`
- `unix`
- `win`
- `win32`
- `win64`
- `x86`
- `x86_64`