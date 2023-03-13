# TUSKit Release checklist

* Update [CHANGELOG.md](http://CHANGELOG.md)
* Update TUSKit.podspec with new version nr. and commit
* Tag update commit
* Make sure to push commits _and_ tag
* Publish updated podspec `pod trunk push TUSKit.podspec`
  * If you're doing this for the first time, register with `pod trunk register ‘<Your email>’ ‘<name>’`
  * If you don't have access but are supposed to have this access, reach out to @kvz