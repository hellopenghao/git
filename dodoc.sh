#!/bin/sh
#
# This script is called from the post-update hook, and when
# the master branch is updated, run in $HOME/git-doc, like
# this:
: <<\END_OF_COMMENTARY

$ cat >hooks/post-update
#!/bin/sh
case " $* " in
*' refs/heads/master '*)
        echo $HOME/git-doc/dodoc.sh | at now
        ;;
esac
exec git-update-server-info
$ chmod +x hooks/post-update

END_OF_COMMENTARY

# $HOME/git-doc is a clone of the git.git repository and
# has the master branch checkd out.  We update the working
# tree and build pre-formatted documentation pages, install
# in doc-htmlpages and doc-manapges subdirectory here.
# These two are their own git repository, and when they are
# updated the updates are pushed back into their own branches
# in git.git repository.

ID=`git-rev-parse --verify refs/heads/master` || exit $?

unset GIT_DIR

PUBLIC=/pub/software/scm/git/docs &&
MASTERREPO=`pwd` &&
DOCREPO=`dirname "$0"` &&
test "$DOCREPO" != "" &&
cd "$DOCREPO" || exit $?

git pull "$MASTERREPO" master &&
test $(git-rev-parse --verify refs/heads/master) == "$ID" &&
NID=$(git-describe --abbrev=4 "$ID") &&
test '' != "$NID" ||  exit $?

# Set up subrepositories
test -d doc-htmlpages || (
	mkdir doc-htmlpages &&
	cd doc-htmlpages &&
	git init-db || exit $?

	if SID=$(git fetch-pack "$MASTERREPO" html)
	then
		git update-ref HEAD `expr "$SID" : '\(.*\) .*'` &&
		git checkout || exit $?
	fi
)
test -d doc-manpages || (
	mkdir doc-manpages &&
	cd doc-manpages &&
	git init-db || exit $?

	if SID=$(git fetch-pack "$MASTERREPO" man)
	then
		git update-ref HEAD `expr "$SID" : '\(.*\) .*'` &&
		git checkout || exit $?
	fi
)
find doc-htmlpages doc-manpages -type d -name '.git' -prune -o \
	-type f -print0 | xargs -0 rm -f

cd Documentation &&
make WEBDOC_DEST="$DOCREPO/doc-htmlpages" install-webdoc >../:html.log 2>&1 &&

if test -d $PUBLIC
then
	make WEBDOC_DEST="$PUBLIC" install-webdoc >>../:html.log 2>&1
else
	echo "* No public html at $PUBLIC"
fi || exit $?

cd ../doc-htmlpages &&
    git add . &&
    if git commit -a -m "Autogenerated HTML docs for $NID"
    then
	git-send-pack "$MASTERREPO" master:refs/heads/html || {
	    echo "* HTML failure"
	    exit 1
	}
    else
	echo "* No changes in html docs"
    fi

cd ../Documentation &&
make man1="$DOCREPO/doc-manpages/man1" man7="$DOCREPO/doc-manpages/man7" \
	install >../:man.log 2>&1 &&

cd ../doc-manpages &&
    git add . &&
    if git commit -a -m "Autogenerated man pages for $NID"
    then
	git-send-pack "$MASTERREPO" master:refs/heads/man || {
	    echo "* man failure"
	    exit 1
        }
    else
    	echo "* No changes in manual pages"
    fi

