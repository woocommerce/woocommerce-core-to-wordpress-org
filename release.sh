#!/bin/sh

echo "-------------------------------------------"
echo "           WOOCOMMERCE RELEASER            "
echo "-------------------------------------------"

# TEST USER SETTINGS
if [ -r $HOME/.wc-deploy ]; then
  echo "User config file read successfully!"
  . $HOME/.wc-deploy
else
  echo "You need create a ~/.wc-deploy file with your GITHUB_ACCESS_TOKEN and ROOT_PATH settings."
  echo "Deploy aborted!"
  exit
fi

if [ -z $GITHUB_ACCESS_TOKEN ]; then
  echo "You need set the GITHUB_ACCESS_TOKEN in your ~/.wc-deploy file."
  echo "Deploy aborted!"
  exit
fi

if [ -z $ROOT_PATH ]; then
  echo "You need set the ROOT_PATH in your ~/.wc-deploy file."
  echo "Deploy aborted!"
  exit
fi

# ASK INFO
read -p "VERSION: " VERSION
read -p "BRANCH: " BRANCH
echo "-------------------------------------------"
read -p "PRESS [ENTER] TO RELEASE VERSION ${VERSION} USING BRANCH ${BRANCH}"

# VARS
PRODUCT_NAME="woocommerce"
PRODUCT_NAME_GIT=${PRODUCT_NAME}"-git"
PRODUCT_NAME_SVN=${PRODUCT_NAME}"-svn"
SVN_REPO="http://plugins.svn.wordpress.org/woocommerce/"
GIT_REPO="git@github.com:woothemes/woocommerce.git"
SVN_PATH=$ROOT_PATH$PRODUCT_NAME_SVN
GIT_PATH=$ROOT_PATH$PRODUCT_NAME_GIT

# CHECKOUT SVN DIR IF NOT EXISTS
if [ ! -d $SVN_PATH ]; then
  echo "No SVN directory found, will do a checkout"
  svn checkout $SVN_REPO $SVN_PATH
fi

# DELETE OLD GIT DIR
rm -Rf $GIT_PATH

# CLONE GIT DIR
echo "Cloning GIT repo"
git clone $GIT_REPO $GIT_PATH --branch ${BRANCH} --single-branch

# MOVE INTO GIT DIR
cd $GIT_PATH

# REMOVE UNWANTED FILES & FOLDERS
echo "Removing unwanted files"
rm -Rf .git
rm -Rf tests
rm -f .gitattributes
rm -f .gitignore
rm -f .gitmodules
rm -f .travis.yml
rm -f Gruntfile.js
rm -f package.json
rm -f .jscrsrc
rm -f .jshintrc
rm -f composer.json
rm -f phpunit.xml
rm -f phpunit.xml.dist
rm -f README.md
rm -Rf apigen
rm -f .coveralls.yml
rm -f .editorconfig
rm -f .scrutinizer.yml
rm -f .travis.yml
rm -f CONTRIBUTING.md

# MOVE INTO SVN DIR
cd $SVN_PATH

# UPDATE SVN
echo "Updating SVN"
svn update

# DELETE TRUNK
echo "Replacing trunk"
rm -Rf trunk/

# COPY GIT DIR TO TRUNK
cp -R $GIT_PATH trunk/

# DO THE ADD ALL NOT KNOWN FILES UNIX COMMAND
svn add --force * --auto-props --parents --depth infinity -q

# DO THE REMOVE ALL DELETED FILES UNIX COMMAND
svn rm $( svn status | sed -e '/^!/!d' -e 's/^!//' )

# COPY TRUNK TO TAGS/$VERSION
svn copy trunk tags/${VERSION}

# DO SVN COMMIT
svn status
echo "svn commit -m \"Release "${VERSION}", see readme.txt for changelog.\""

# REMOVE THE GIT DIR
echo "Removing GIT dir"
rm -Rf $GIT_PATH

# CREATE THE GITHUB RELEASE
echo "Creating GITHUB release"
API_JSON=$(printf '{"tag_name": "%s","target_commitish": "%s","name": "%s","body": "Release of version %s","draft": false,"prerelease": false}' $VERSION $BRANCH $VERSION $VERSION)
curl --data "$API_JSON" https://api.github.com/repos/woothemes/${PRODUCT_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN}

# DONE, BYE
echo "WOOCOMMERCE RELEASER DONE"
