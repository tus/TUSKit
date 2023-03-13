# Roadmap

- [x] Release version with latest changes (changes: https://github.com/tus/TUSKit/compare/3.1.4...main, relevant issues: https://github.com/tus/TUSKit/issues/138, https://github.com/tus/TUSKit/issues/141 and https://community.transloadit.com/t/ios-tus-client-version-update/16395/3)
- [ ] Create a documentation describing the release process (pods, swift package manager?)
- [ ] Update metadata (author, language, repo) in CocoaPods: https://cocoapods.org/pods/TUSKit
- [ ] Create an example app where TUSKit is used in (would show you how to use the client from a customer’s point of view. Should help evolve the API)
  - [x] Add pause / resume functionality
  - [x] Add progress indicator
  - [x] Add ability to resume uploads from previous app session
  - [ ] Add ability to upload files in background
- [ ] Review and address issues & PRs in GitHub until there are zero
- [ ] ~~Create a release blog post on tus.io with the changes from 2.x to 3.x and some usage examples~~
- [ ] Fix CI tests
- [ ] Think about automating releasing using CI
