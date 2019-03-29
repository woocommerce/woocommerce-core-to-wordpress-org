#!/bin/sh
# WooCommerce releaser script

# Variables
RELEASER_VERSION="1.0.0"
RELEASER_PATH=$(pwd)
BUILD_PATH="${RELEASER_PATH}/build"
PRODUCT_NAME="woocommerce"
GITHUB_ORG="woocommerce"
SVN_REPO="http://plugins.svn.wordpress.org/${PRODUCT_NAME}/"
GIT_REPO="https://github.com/${GITHUB_ORG}/${PRODUCT_NAME}.git"
SVN_PATH="${BUILD_PATH}/${PRODUCT_NAME}-svn"
GIT_PATH="${BUILD_PATH}/${PRODUCT_NAME}-git"
IS_PRE_RELEASE="false"
SKIP_GH=false
SKIP_SVN=false
SKIP_SVN_TRUNK=false
UPDATE_STABLE_TAG=false

# Functions
# Check if string contains substring
is_substring() {
  case "$2" in
    *$1*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Echo colorized strings
#
# Color codes:
# 0 - black
# 1 - red
# 2 - green
# 3 - yellow
# 4 - blue
# 5 - magenta
# 6 - cian
# 7 - white
echo_colorized() {
  echo "$(tput setaf $1)$2$(tput sgr0)"
}

# Sync dest files
copy_dest_files() {
  cd $2
  rsync ./ $3/$1/ --recursive --verbose --delete --delete-excluded \
    --exclude=".*/" \
    --exclude="*.md" \
    --exclude=".*" \
    --exclude="composer.*" \
    --exclude="*.lock" \
    --exclude=/vendor/ \
    --exclude=apigen.neon \
    --exclude=apigen/ \
    --exclude=CHANGELOG.txt \
    --exclude=Gruntfile.js \
    --exclude=node_modules/ \
    --exclude=none \
    --exclude=package.json \
    --exclude=package-lock.json \
    --exclude=phpcs.xml \
    --exclude=phpunit.xml \
    --exclude=phpunit.xml.dist \
    --exclude=README.md \
    --exclude=tests/
  cd $3
}

echo_colorized 5 "-------------------------------------------"
echo_colorized 5 "           WOOCOMMERCE RELEASER            "
echo_colorized 5 "-------------------------------------------"

# Set user options
while [ ! $# -eq 0 ]; do
  case "$1" in
    -h|--help)
      echo "Usage: ./release.sh [options]"
      echo
      echo "GitHub to WordPress.org command line client."
      echo
      echo "Examples:"
      echo "./release.sh       # Regular release on GitHub and wp.org"
      echo "./release.sh -t -u # Release a \"Stable tag\", and update trunk/readme.txt"
      echo "./release.sh -s    # Release only on GitHub"
      echo "./release.sh -g    # Release only on wp.org"
      echo
      echo "Available options:"
      echo "  -h [--help]              Shows help message"
      echo "  -v [--version]           Shows releaser version"
      echo "  -g [--skip-gh]           Skip GitHub release/tag creation"
      echo "  -s [--skip-svn]          Skip release on SVN"
      echo "  -t [--svn-tag-only]      Release only a SVN tag"
      echo "  -u [--svn-up-stable-tag] Update \"Stable tag\" in trunk/readme.txt"
      echo "  -c [--clean]             Clean build directory"
      exit 0
      ;;
    -v|--version)
      echo "Version ${RELEASER_VERSION}"
      exit 0
      ;;
    -g|--skip-gh)
      SKIP_GH=true
      ;;
    -s|--skip-svn)
      SKIP_SVN=true
      ;;
    -t|--svn-tag-only)
      SKIP_SVN_TRUNK=true
      ;;
    -u|--svn-up-stable-tag)
      UPDATE_STABLE_TAG=true
      ;;
    -c|--clean)
      rm -rf $BUILD_PATH
      echo_colorized 2 "Build directory cleaned!"
      ;;
  esac
  shift
done

# Get user settings
if [ -r "${RELEASER_PATH}/.settings" ]; then
  echo ".settings file read successfully!"
  . "${RELEASER_PATH}/.settings"
elif [ -r $HOME/.wc-deploy ]; then
  # Legacy config file, keep for backwards compatibility
  echo ".wc-deploy file read successfully!"
  . $HOME/.wc-deploy
else
  echo_colorized 1 "You need create a .settings file and fill with your GITHUB_ACCESS_TOKEN settings."
  echo
  echo_colorized 1 "Use the follow command to create your .settings file:"
  echo_colorized 1 "cp .settings-sample .settings"
  echo
  echo_colorized 1 "Deploy aborted!"
  exit 1
fi

if [ -z $GITHUB_ACCESS_TOKEN ]; then
  echo_colorized 1 "You need set the GITHUB_ACCESS_TOKEN in your .settings file."
  echo_colorized 1 "Deploy aborted!"
  exit 1
fi

# Ask info
echo_colorized 2 "Starting release..."
read -p "VERSION: " VERSION
read -p "BRANCH: " BRANCH
echo "-------------------------------------------"
echo "You are about to release \"${VERSION}\" based on \"${BRANCH}\" GIT branch."
read -r -p "Are you sure? [y/N]: " PROCEED

if [ $(echo "${PROCEED:-n}" | tr [:upper:] [:lower:]) != "y" ]; then
  echo_colorized 1 "Release cancelled!"
  exit 1
fi

echo_colorized 2 "Confirmed! Starting process..."

# Create SVN release
if ! $SKIP_SVN; then
  # Create build directory if does not exists
  if [ ! -d $BUILD_PATH ]; then
    mkdir -p $BUILD_PATH
  fi

  # Delete old GIT directory
  rm -rf $GIT_PATH

  # Clone GIT repository
  echo_colorized 2 "Cloning GIT repository..."
  git clone $GIT_REPO $GIT_PATH --branch ${BRANCH} --single-branch || exit "$?"

  # Run grunt
  echo_colorized 2 "Running JS Build..."
  cd $GIT_PATH
  npm install
  npm run build || exit "$?"

  # Checkout SVN repository if not exists
  if [ ! -d $SVN_PATH ]; then
    echo_colorized 2 "No SVN directory found, fetching files..."
    # Checkout project without any file
    svn co --depth=files $SVN_REPO $SVN_PATH

    cd $SVN_PATH

    # Fetch main directories
    svn up assets branches trunk

    # Fetch tags directories without content
    svn up --set-depth=immediates tags
    # To fetch content for a tag, use:
    # svn up --set-depth=infinity tags/<tag_number>
  else
    # Update SVN
    cd $SVN_PATH
    echo_colorized 2 "Updating SVN..."
    svn up
  fi

  # Copy GIT directory to trunk
  if ! $SKIP_SVN_TRUNK; then
    echo_colorized 2 "Copying project files to SVN trunk..."
    copy_dest_files "trunk" $GIT_PATH $SVN_PATH
  else
    echo_colorized 2 "Copying project files to SVN tags/${VERSION}..."
    copy_dest_files "tags/${VERSION}" $GIT_PATH $SVN_PATH

    # Update stable tag on trunk/readme.txt
    if $UPDATE_STABLE_TAG; then
      echo_colorized 2 "Updating \"Stable tag\" to ${VERSION} on trunk/readme.txt..."
      sed -i "6s/.*/Stable tag: ${VERSION}/" trunk/readme.txt
    fi
  fi

  # Do the remove all deleted files
  svn st | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2"@"}' | xargs svn rm

  # Do the add all not know files
  svn st | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2"@"}' | xargs svn add

  # Copy trunk to tag/$VERSION
  if ! $SKIP_SVN_TRUNK && [ ! -d "tags/${VERSION}" ]; then
    echo_colorized 2 "Creating SVN tags/${VERSION}..."
    svn cp trunk tags/${VERSION}
  fi

  # Remove the GIT directory
  echo_colorized 2 "Removing GIT directory..."
  rm -rf $GIT_PATH
fi

# Create the GitHub release
if ! $SKIP_GH; then
  echo_colorized 2 "Creating GitHub release..."

  # Check if is a pre-release.
  if is_substring "-" ${VERSION}; then
    IS_PRE_RELEASE="true"
  fi

  API_JSON=$(printf '{"tag_name": "%s","target_commitish": "%s","name": "%s","body": "Release of version %s","draft": false,"prerelease": %s}' $VERSION $BRANCH $VERSION $VERSION $IS_PRE_RELEASE)

  curl --data "$API_JSON" https://api.github.com/repos/${GITHUB_ORG}/${PRODUCT_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN}
fi

if ! $SKIP_SVN; then
  # SVN commit messsage
  echo_colorized 2 "Ready to commit into WordPress.org Plugin's Directory!"
  echo "Run the follow commads to commit:"
  echo "cd ${SVN_PATH}"
  echo "svn ci -m \"Release "${VERSION}", see readme.txt for changelog.\""
fi

# Done
echo_colorized 2 "Release complete!"
