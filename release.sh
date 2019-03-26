#!/bin/sh

echo "-------------------------------------------"
echo "           WOOCOMMERCE RELEASER            "
echo "-------------------------------------------"

# Test user settings
if [ -r $HOME/.wc-deploy ]; then
  echo "User config file read successfully!"
  . $HOME/.wc-deploy
else
  echo "You need create a ~/.wc-deploy file with your GITHUB_ACCESS_TOKEN settings."
  echo "Deploy aborted!"
  exit
fi

if [ -z $GITHUB_ACCESS_TOKEN ]; then
  echo "You need set the GITHUB_ACCESS_TOKEN in your ~/.wc-deploy file."
  echo "Deploy aborted!"
  exit
fi

# Variables
BUILD_PATH=$(pwd)"/build"
PRODUCT_NAME="woocommerce"
SVN_REPO="http://plugins.svn.wordpress.org/${PRODUCT_NAME}/"
GIT_REPO="https://github.com/woocommerce/${PRODUCT_NAME}.git"
SVN_PATH="${BUILD_PATH}/${PRODUCT_NAME}-svn"
GIT_PATH="${BUILD_PATH}/${PRODUCT_NAME}-git"
IS_PRE_RELEASE="false"
SKIP_GH=false
SKIP_SVN=false
SKIP_SVN_TRUNK=false

# Set user options
while [ ! $# -eq 0 ]; do
  case "$1" in
    -h|--help)
      echo "Help Message" # TODO
      exit;
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
  esac
  shift
done

# Ask info
read -p "VERSION: " VERSION
read -p "BRANCH: " BRANCH
echo "-------------------------------------------"
echo "You are about to release \"${VERSION}\" based on \"${BRANCH}\" GIT branch."
read -r -p "Are you sure? [y/N]: " PROCEED

if [ $(echo "${PROCEED:-n}" | tr [:upper:] [:lower:]) != "y" ]; then
  echo "Release cancelled!"
  exit 1
fi

echo "Confirmed! Starting process..."

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

# Sync dest files
copy_dest_files() {
  cd $GIT_PATH
  rsync ./ $SVN_PATH/$1/ --recursive --verbose --delete --delete-excluded \
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
  cd $SVN_PATH
}

# Run JS build.
run_js_build() {
  echo "Running JS Build..."
  cd $GIT_PATH
  npm install
  npm run build || exit "$?"
}

# Create SVN release
create_svn_release() {
  # Create build directory if does not exists
  if [ ! -d $BUILD_PATH ]; then
    mkdir -p $BUILD_PATH
  fi

  # Delete old GIT directory
  rm -Rf $GIT_PATH

  # Clone GIT repository
  echo "Cloning GIT repository..."
  git clone $GIT_REPO $GIT_PATH --branch ${BRANCH} --single-branch || exit "$?"

  # Run grunt
  run_js_build

  # Checkout SVN repository if not exists
  if [ ! -d $SVN_PATH ]; then
    echo "No SVN directory found, fetching files..."
    # Checkout project in non recursive way (-N or --non-recursive)
    svn co $SVN_REPO -N $SVN_PATH

    cd $SVN_PATH

    # Fetch main directories
    svn up assets
    svn up branches
    svn up trunk

    # Fetch tags directories without content
    svn up --set-depth immediates tags
    # To fetch content for a tag, use:
    # svn up --set-depth infinity tags/<tag_number>
  else
    # Update SVN
    cd $SVN_PATH
    echo "Updating SVN..."
    svn up
  fi

  # Copy GIT directory to trunk
  if ! $SKIP_SVN_TRUNK; then
    copy_dest_files "trunk"
  else
    copy_dest_files "tags/${VERSION}"
  fi

  # Do the remove all deleted files
  svn st | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2"@"}' | xargs svn rm

  # Do the add all not know files
  svn st | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2"@"}' | xargs svn add

  if ! $SKIP_SVN_TRUNK; then
    # Copy trunk to tag/$VERSION
    if [ ! -d "tags/${VERSION}" ]; then
      svn cp trunk tags/${VERSION}
    else
      # Just copy again the files if tag/$VERSION already exists
      # This prevents creation of tag/$VERSION/trunk directory
      copy_dest_files "tags/${VERSION}"
    fi
  fi

  # Remove the GIT directory
  echo "Removing GIT directory..."
  rm -Rf $GIT_PATH
}

# Create GH release
create_gh_release() {
  echo "Creating GitHub release..."

  # Check if is a pre-release.
  if is_substring "-" ${VERSION}; then
    IS_PRE_RELEASE="true"
  fi

  API_JSON=$(printf '{"tag_name": "%s","target_commitish": "%s","name": "%s","body": "Release of version %s","draft": false,"prerelease": %s}' $VERSION $BRANCH $VERSION $VERSION $IS_PRE_RELEASE)

  curl --data "$API_JSON" https://api.github.com/repos/woocommerce/${PRODUCT_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN}
}

if ! $SKIP_SVN; then
  create_svn_release
fi

# Create the GitHub release
if ! $SKIP_GH; then
  create_gh_release
fi

if ! $SKIP_SVN; then
  # SVN commit messsage
  echo "Ready to commit into WordPress.org Plugin's Directory!"
  echo "Run the follow commads to commit:"
  echo "cd ${SVN_PATH}"
  echo "svn ci -m \"Release "${VERSION}", see readme.txt for changelog.\""
fi

# Done
echo "Release complete!"
