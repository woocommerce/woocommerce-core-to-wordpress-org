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

# Functions
# Check if string contains substring
is_substring() {
  case "$2" in
    *$1*) return 0;;
    *) return 1;;
  esac
}

# Ask info
read -p "VERSION: " VERSION
read -p "BRANCH: " BRANCH
echo "-------------------------------------------"
read -r -p "You are about to release \"${VERSION}\" based on \"${BRANCH}\" GIT branch. Are you sure? [y/N]" RESPONSE
case "$RESPONSE" in
  [yY])
    echo "Accepted and moving on..."
    ;;
  *)
    exit;
    ;;
esac

# Variables
BUILD_PATH=$(pwd)"/build"
PRODUCT_NAME="woocommerce"
PRODUCT_NAME_GIT=${PRODUCT_NAME}"-git"
PRODUCT_NAME_SVN=${PRODUCT_NAME}"-svn"
SVN_REPO="http://plugins.svn.wordpress.org/woocommerce/"
GIT_REPO="https://github.com/woocommerce/woocommerce.git"
SVN_PATH="$BUILD_PATH/$PRODUCT_NAME_SVN"
GIT_PATH="$BUILD_PATH/$PRODUCT_NAME_GIT"
IS_PRE_RELEASE="false"

# Check if is a pre-release.
if is_substring "-" ${VERSION}; then
  IS_PRE_RELEASE="true"
fi

# Create build directory if does not exists
if [ ! -d $BUILD_PATH ]; then
  mkdir -p $BUILD_PATH
fi

# Checkout SVN repository if not exists
if [ ! -d $SVN_PATH ]; then
  echo "No SVN directory found, will do a checkout..."
  svn checkout $SVN_REPO $SVN_PATH
fi

# Delete old GIT directory
rm -Rf $GIT_PATH

# Clone GIT repository
echo "Cloning GIT repository..."
git clone $GIT_REPO $GIT_PATH --branch ${BRANCH} --single-branch || exit "$?"

# Run grunt
echo "Running JS Build..."
cd $GIT_PATH
npm install
npm run build || exit "$?"

# Move into SVN directory
cd $SVN_PATH

# Update SVN
echo "Updating SVN..."
svn update

# Copy GIT directory to trunk
cd $GIT_PATH
rsync ./ $SVN_PATH/trunk/ --recursive --verbose --delete --delete-excluded \
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

# Do the remove all deleted files
svn rm $( svn status | sed -e '/^!/!d' -e 's/^!//' )

# Do the add all not know files
svn add --force * --auto-props --parents --depth infinity -q

# Copy trunk to tag/$VERSION
svn copy trunk tags/${VERSION}

# Remove the GIT directory
echo "Removing GIT directory..."
rm -Rf $GIT_PATH

# Create the GitHub release
echo "Creating GITHUB release..."
API_JSON=$(printf '{"tag_name": "%s","target_commitish": "%s","name": "%s","body": "Release of version %s","draft": false,"prerelease": %s}' $VERSION $BRANCH $VERSION $VERSION $IS_PRE_RELEASE)
curl --data "$API_JSON" https://api.github.com/repos/woocommerce/${PRODUCT_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN}

# Do svn commit
svn status
echo "Ready to commit into WordPress.org Plugin's Directory!"
echo "Run the follow commads to commit:"
echo "cd ${SVN_PATH}"
echo "svn commit -m \"Release "${VERSION}", see readme.txt for changelog.\""

# Done
echo "WooCommerce releaser done"
