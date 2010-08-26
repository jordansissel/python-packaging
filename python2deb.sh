#!/bin/sh

if [ "$1" = "-h" ] ; then
  echo "Usage: $0 [package]"
  echo "If no package is given, 'setup.py' is searched for in $PWD."
  echo "If package given, we download with easy_install then build a package."
  exit 0
fi

if [ "0$#" -ne 0 ] ; then
  easy_install --editable --build-directory . "$@"
  cd $1
fi

if [ ! -r "setup.py" ] ; then
  echo "No setup.py found in current directory ($PWD)"
  exit 1
fi

# I know, this is pretty crappy, but it's quicker than monkeypatching or
# extending distutils.
eval "$(python <<PYTHON)"
import pipes

def setup(**kwds):
  for k in kwds:
    print "%s=%s" % (k, pipes.quote(str(kwds[k])))
  if "requires" in kwds:
    print "requires=%s" % pipes.quote((", ".join(["python-%s" % x for x in kwds["requires"]])))

$(
  # Include the setup.py, minus distutils.
  sed -re 's/(import .*)setup, */\1/; s/^.*import setup$//;' setup.py
)
PYTHON

if [ -z "$name" -o -z "$version" ] ; then
  echo "Unable to find name, version, etc..."
  exit 1
fi

# debuild requires package names be lowercase.
name=$(echo "$name" | tr A-Z a-z)
set -e
set -x
dh_make -s -n -c blank -e $USER -p "python-${name}_${version}"
sed -i -e "/Depends:.*$requires/! { s/^Depends: .*/&, $requires/ }" debian/control
debuild -us -uc
