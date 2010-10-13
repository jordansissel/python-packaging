#!/bin/sh

if [ "$1" = "-h" ] ; then
  echo "Usage: $0 [package]"
  echo "If no package is given, 'setup.py' is searched for in $PWD."
  echo "If package given, we download with easy_install then build a package."
  exit 0
fi

# debuild requires package names be lowercase.
if [ "0$#" -ne 0 ] ; then
  easy_install --editable --build-directory . "$@"
  cd $(ls -td */ | sed -ne '1p')
fi

if [ ! -r "setup.py" ] ; then
  echo "No setup.py found in current directory ($PWD)"
  exit 1
fi

if [ ! -z "$PATCHES" ] ; then
  sh $PATCHES
fi

# I know, this is pretty crappy, but it's quicker than monkeypatching or
# extending distutils.
ed setup.py << ED_IS_AWESOME
/^ *setup *(/i
import pipes

def setup(**kwds):
  for k in kwds:
    print "%s=%s" % (k, pipes.quote(str(kwds[k])))
  if "requires" in kwds:
    print "requires=%s" % pipes.quote((", ".join(["python-%s" % x for x in kwds["requires"]])))

.
w hacked_setup.py
q
ED_IS_AWESOME

eval "$(python hacked_setup.py)"

if [ -z "$name" -o -z "$version" ] ; then
  echo "Unable to find name, version, etc..."
  exit 1
fi

set -e
set -x
name=$(echo "$name" | tr A-Z a-z)
release="$(date +%Y%m%d.%H%M%S)"
dh_make -s -n -c blank -e $USER -p "python-${name}_${version}-${release}" < /dev/null
sed -i -e "/Depends:.*$requires/! { s/^Depends: .*/&, $requires/ }" debian/control
debuild -us -uc
