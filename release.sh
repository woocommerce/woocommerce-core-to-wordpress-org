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
GIT_REPO="git@github.com:woocommerce/woocommerce.git"
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

# MOVE INTO SVN DIR
cd $SVN_PATH

# UPDATE SVN
echo "Updating SVN"
svn update

# COPY GIT DIR TO TRUNK
cd $GIT_PATH
# rsync ./ $SVN_PATH/tags/${VERSION}/ --recursive --verbose --delete --delete-excluded \
rsync ./ $SVN_PATH/trunk/ --recursive --verbose --delete --delete-excluded \
	--exclude=.babelrc \
	--exclude=.codeclimate.yml \
	--exclude=.coveralls.yml \
	--exclude=.editorconfig \
	--exclude=.git/ \
	--exclude=.gitattributes \
	--exclude=.github \
	--exclude=.gitignore \
	--exclude=.gitmodules \
	--exclude=.jscrsrc \
	--exclude=.jshintrc \
	--exclude=.scrutinizer.yml \
	--exclude=.stylelintrc \
	--exclude=.travis.yml \
	--exclude=.wordpress-org \
	--exclude=apigen.neon \
	--exclude=apigen/ \
	--exclude=CHANGELOG.txt \
	--exclude=composer.json \
	--exclude=composer.lock \
	--exclude=CONTRIBUTING.md \
	--exclude=Gruntfile.js \
	--exclude=package.json \
	--exclude=phpcs.ruleset.xml \
	--exclude=phpunit.xml \
	--exclude=phpunit.xml.dist \
	--exclude=README.md \
	--exclude=tests/

cd $SVN_PATH

# DO THE REMOVE ALL DELETED FILES UNIX COMMAND
svn rm $( svn status | sed -e '/^!/!d' -e 's/^!//' )

# DO THE ADD ALL NOT KNOWN FILES UNIX COMMAND
svn add --force * --auto-props --parents --depth infinity -q

# COPY TRUNK TO TAGS/$VERSION
svn copy trunk tags/${VERSION}

# REMOVE THE GIT DIR
echo "Removing GIT dir"
rm -Rf $GIT_PATH

# CREATE THE GITHUB RELEASE
echo "Creating GITHUB release"
API_JSON=$(printf '{"tag_name": "%s","target_commitish": "%s","name": "%s","body": "Release of version %s","draft": false,"prerelease": false}' $VERSION $BRANCH $VERSION $VERSION)
curl --data "$API_JSON" https://api.github.com/repos/woocommerce/${PRODUCT_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN}

# DO SVN COMMIT
svn status
echo "svn commit -m \"Release "${VERSION}", see readme.txt for changelog.\""

# DONE, BYE
echo "WOOCOMMERCE RELEASER DONE"
