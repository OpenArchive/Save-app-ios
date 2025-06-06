#  Save by OpenArchive

https://open-archive.org/save/

Save is an open-source app created by OpenArchive to help you securely verify, share, and archive your mobile media. It's free, open-source, and available for iOS and Android.

## Author

Benjamin Erhart, Die Netzarchitekten e.U.
https://die.netzarchitekten.com/

## Translators

These people kindly donored their time and work to translate the app and surrounding material:

- French: yahoe.001, n.perraut, soizicat
- Spanish: yamilabadu, josephdg18, m_rey, Elos, fr0st, ianvatega, losalim
- Russian: palyanitsin, viktoriiasavchuk
- Turkish: kayazeren
- Arabic: ahmedessamdev, mahmoud_th, Sammy_Adams, sec.xyx
- Persian: ahangarha, voxp
- Italian: RickDeckard
- Ukrainian: andriykopanytsia, losalim, viktoriiasavchuk
- German:  m_rey

Thank you very much, folks!

## Copyright

2019 - 2024 OpenArchive
https://open-archive.org/

## Contributing

If you would like to contribute code, please consider the following:

- Contributions will only be considered when sent via a Git pull request.
- Stick to the general formatting of the rest of the source code. If you find inconsistencies, your 
improvements are welcome via pull requests.
- Stick to the naming conventions of the rest of code. Think hard about naming.
- Refactor early, don't repeat yourself.
- Spaghetti code, 1k+ line methods and similar abominations won't be accepted.
- Don't be too clever. Code which isn't understandable by anyone but you while writing it,
won't be acepted. Document the non-obvious!
- If you find violations of these rules in the existing code, again: Happy to see your pull requests!
- Contributor License Agreement: If you send pull requests, please state, that you grant 
OpenArchive the non-revocable right to use your code for this project in any way OpenArchive 
deems necessary. This includes, re-licensing under another license.

## Code of Conduct
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](https://openarchive.github.io/Code-of-Conduct/) 

## Dev Stuff

### Build

You'll need to have [CocoaPods](https://cocoapods.org) and Xcode installed.
We recommend to install CocoaPods via [Homebrew](https://brew.sh):

```sh
brew install cocoapods
```

Prepare the workspace like this:

```sh
git clone https://github.com/OpenArchive/Save-app-ios.git
cd Save-app-ios
pod install
open Save.xcworkspace
```

Then fill in the missing build configuration in [Shared/Config.xcconfig](Shared/Config.xcconfig)!

Now you should be able to build.


### Internet Archive S3 reference:
https://archive.org/help/abouts3.txt
https://github.com/vmbrasseur/IAS3API
http://internetarchive.readthedocs.io/en/latest/api.html

### SVG -> PDF:
http://www.rexfeng.com/blog/2018/08/using-svg-pdf-assets-in-your-ios-app/

```shell
brew install python3 cairo pango gdk-pixbuf libffi
pip3 install cairosvg

cairosvg icon.svg -o icon.pdf
```
