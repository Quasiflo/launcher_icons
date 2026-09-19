# Changelog

## [0.15.0](https://github.com/Quasiflo/launcher_icons/compare/launcher_icons-v0.14.4...launcher_icons-v0.15.0) (2026-09-19)


### ⚠ BREAKING CHANGES

* remove dead hasPlatformConfig gate
* remove dead minSdk apparatus
* rebrand flutter_launcher_icons to launcher_icons
* remove deprecated windows.icon_size, flutter_icons key and main shim
* modern universal iOS icon set for all paths, drop legacy list (fluttercommunity/flutter_launcher_icons#528)
* nested android/ios config schema, v3 breaking change (fluttercommunity/flutter_launcher_icons#394)

### Features

* accept http(s) image URLs for icon sources (fluttercommunity/flutter_launcher_icons[#511](https://github.com/Quasiflo/launcher_icons/issues/511)) ([c764545](https://github.com/Quasiflo/launcher_icons/commit/c76454569bfe5de288731acb40fffeec6892405d))
* add android notification icon ([9be7f55](https://github.com/Quasiflo/launcher_icons/commit/9be7f55d38600f5f4171984f9f94bf59d4bbda23))
* add config options for linux ([8da01fa](https://github.com/Quasiflo/launcher_icons/commit/8da01faf077b6884f4c3d504ae2d59bd62fd7771))
* add ios & macos liquid glass further configs ([d57c215](https://github.com/Quasiflo/launcher_icons/commit/d57c2158f3d654e4a9f8df268f9f20b924fa8692))
* add Linux support ([5766570](https://github.com/Quasiflo/launcher_icons/commit/5766570a94d2b8761c72316c979639c979da435e))
* add Linux support (fluttercommunity/flutter_launcher_icons[#647](https://github.com/Quasiflo/launcher_icons/issues/647)) ([5766570](https://github.com/Quasiflo/launcher_icons/commit/5766570a94d2b8761c72316c979639c979da435e))
* add liquid glass .icon support for macOS ([c7295fc](https://github.com/Quasiflo/launcher_icons/commit/c7295fc35e92117d60cab3280a7151038c28b78c))
* add version flag ([d4b211c](https://github.com/Quasiflo/launcher_icons/commit/d4b211cf9ff0df990fe1695e92d059faa04a3475))
* added support for android 13+ themed icons (fluttercommunity/flutter_launcher_icons[#497](https://github.com/Quasiflo/launcher_icons/issues/497)) ([8c45d48](https://github.com/Quasiflo/launcher_icons/commit/8c45d485515dafd9fb5f4682d3b49f63a47c5416))
* android adaptive_icon_round opt-in and play_store_icon sidecar ([540930b](https://github.com/Quasiflo/launcher_icons/commit/540930b4f8e2cbb5e9483ff0a711c892631cee8c))
* build web favicon from a different source image (fluttercommunity/flutter_launcher_icons[#519](https://github.com/Quasiflo/launcher_icons/issues/519)) ([1b28150](https://github.com/Quasiflo/launcher_icons/commit/1b281500750eebc81cbb0a644091630b4aebb66f))
* **cli-option:** added --prefix option ([0381010](https://github.com/Quasiflo/launcher_icons/commit/0381010388e22f2aa73ebf9a60b33363ac7f7774))
* command to generate config file template ([48cf387](https://github.com/Quasiflo/launcher_icons/commit/48cf3870a8a5fa40a1617657ea8dbd7a484683fe))
* **configs:** added new configs to `FlutterLauncherIconsConfig` ([2547d96](https://github.com/Quasiflo/launcher_icons/commit/2547d967f81186dabf33307dbbf94ffaad8643b9))
* configurable web favicon size (fluttercommunity/flutter_launcher_icons[#614](https://github.com/Quasiflo/launcher_icons/issues/614)) ([6b3027b](https://github.com/Quasiflo/launcher_icons/commit/6b3027bc492f847cf90eeaea1b1955dd7aeed281))
* Configure dark and tinted mode icons for iOS 18+ (fluttercommunity/flutter_launcher_icons[#569](https://github.com/Quasiflo/launcher_icons/issues/569)) ([4e66457](https://github.com/Quasiflo/launcher_icons/commit/4e66457dafbede365801a1cd9681b8128765f24c))
* continuous-corner squircle mask for rounded_corners ([7240143](https://github.com/Quasiflo/launcher_icons/commit/7240143a59703a7da53b9bd7bbfb075cbd7c108f))
* custom xcodeproj path for renamed Xcode projects (fluttercommunity/flutter_launcher_icons[#637](https://github.com/Quasiflo/launcher_icons/issues/637)) ([84e4b33](https://github.com/Quasiflo/launcher_icons/commit/84e4b33c3e4c96d3d1bab557446d8e8207819643))
* declare flavor variants as launcher_icons-&lt;flavor&gt; sections ([4517781](https://github.com/Quasiflo/launcher_icons/commit/45177819c93204bdeee4a43119ab0c4594a24226))
* dedicated web image_path_maskable source with padded fallback ([ca1233d](https://github.com/Quasiflo/launcher_icons/commit/ca1233d1c1610c688b26cf3cae1105f6005edb8c))
* display command to run to use config file ([bdaeb53](https://github.com/Quasiflo/launcher_icons/commit/bdaeb535722b70a1c61945a62b55f1f2012e4ec9))
* emit favicon.ico alongside favicon.png (fluttercommunity/flutter_launcher_icons[#540](https://github.com/Quasiflo/launcher_icons/issues/540)) ([c20ee1d](https://github.com/Quasiflo/launcher_icons/commit/c20ee1d8614937df8bc456b292d3845caf2dcae2))
* extend & refactor web to include all potential iconography ([4a40a12](https://github.com/Quasiflo/launcher_icons/commit/4a40a12179a3ea34fd18a9afe509e8defb00c027))
* flavor-aware macOS icon sets (fluttercommunity/flutter_launcher_icons[#638](https://github.com/Quasiflo/launcher_icons/issues/638)) ([cd6d1fc](https://github.com/Quasiflo/launcher_icons/commit/cd6d1fcf50637ae0a37d3d411e1bcabea9afe4c3))
* fli cli improvement ([dfe594d](https://github.com/Quasiflo/launcher_icons/commit/dfe594db479a062f79d1c37fece8e52ce3153cb3))
* improve windows icon generation capabilities ([6d63f9b](https://github.com/Quasiflo/launcher_icons/commit/6d63f9b5858df805f2f858a55b292b8f1e6008e7))
* ios xcconfig flavor mode with hardened pbxproj matching ([17c7b1f](https://github.com/Quasiflo/launcher_icons/commit/17c7b1fd6da0d26b4c98295062cc74e2dfb65f50))
* linux derives a runtime raster from SVG sources ([82ab206](https://github.com/Quasiflo/launcher_icons/commit/82ab206ee23186858788ed3be20d145d8a170e65))
* linux hicolor tree, desktop entries, and snap packaging ([428a2a0](https://github.com/Quasiflo/launcher_icons/commit/428a2a01eb4404d8adb62bf893282e0979a9fd89))
* liquid glass icon support (fluttercommunity/flutter_launcher_icons[#650](https://github.com/Quasiflo/launcher_icons/issues/650)) ([a4777c4](https://github.com/Quasiflo/launcher_icons/commit/a4777c41fad96269011c8cf2ab3c900dbc3db680))
* liquid glass lighting, refractivity, and specular placement ([72e890b](https://github.com/Quasiflo/launcher_icons/commit/72e890b3505b2c16e23c9429e1faa3c89afa7791))
* liquid glass per-appearance layer specializations ([06bf883](https://github.com/Quasiflo/launcher_icons/commit/06bf883f22ee68e757f4c24ee4f68b2d04396a4a))
* **logger:** added logger ([b3fbd4f](https://github.com/Quasiflo/launcher_icons/commit/b3fbd4f4e47e4d046045731913e77c8e31b25f1e))
* macOS padding and rounded-corner icon options (fluttercommunity/flutter_launcher_icons[#463](https://github.com/Quasiflo/launcher_icons/issues/463), fluttercommunity/flutter_launcher_icons[#655](https://github.com/Quasiflo/launcher_icons/issues/655)) ([c5679ab](https://github.com/Quasiflo/launcher_icons/commit/c5679ab4525f2978d23d1f98cdf9ef7e189252ea))
* **macos:** added support for macos icons ([9e8e13b](https://github.com/Quasiflo/launcher_icons/commit/9e8e13b4a7ec504c8a6c5eb3e226723971b75d4e))
* modern universal iOS icon set for all paths, drop legacy list (fluttercommunity/flutter_launcher_icons[#528](https://github.com/Quasiflo/launcher_icons/issues/528)) ([7b06517](https://github.com/Quasiflo/launcher_icons/commit/7b06517e248d1f711e6de0de0a4b7406f30de039))
* multi-layer liquid glass icons with per-layer composition ([3e1b755](https://github.com/Quasiflo/launcher_icons/commit/3e1b755ece642030ffcb39fbf1cfce9683a96cd9))
* multi-size favicon.ico with opt-out and CSS hex validation ([2f438be](https://github.com/Quasiflo/launcher_icons/commit/2f438be1b8472052f1be824826e17766f98bebb5))
* multi-size windows .ico by default, deprecate icon_size (fluttercommunity/flutter_launcher_icons[#651](https://github.com/Quasiflo/launcher_icons/issues/651)) ([0778d78](https://github.com/Quasiflo/launcher_icons/commit/0778d78da741d87c2ada1908b8f20e92c90fb936))
* nested android/ios config schema, v3 breaking change (fluttercommunity/flutter_launcher_icons[#394](https://github.com/Quasiflo/launcher_icons/issues/394)) ([29533f7](https://github.com/Quasiflo/launcher_icons/commit/29533f79f9b60145a3f2ac339049106957e91112))
* non-root flavor configuration file discovery (fluttercommunity/flutter_launcher_icons[#664](https://github.com/Quasiflo/launcher_icons/issues/664)) ([55493e7](https://github.com/Quasiflo/launcher_icons/commit/55493e72f51ae3d44fba6dd6c67ab74bbc142a9b))
* route status output through FLILogger with print fallback (fluttercommunity/flutter_launcher_icons[#552](https://github.com/Quasiflo/launcher_icons/issues/552)) ([bb3669c](https://github.com/Quasiflo/launcher_icons/commit/bb3669cc32466d2e716afbfd78cc5fcafb5ac72a))
* shared FLIException base class for package errors (fluttercommunity/flutter_launcher_icons[#378](https://github.com/Quasiflo/launcher_icons/issues/378)) ([72cea01](https://github.com/Quasiflo/launcher_icons/commit/72cea017e9d68613a40ead384a6dc6830391a560))
* single-size iOS icon mode (fluttercommunity/flutter_launcher_icons[#592](https://github.com/Quasiflo/launcher_icons/issues/592)) ([b4013c9](https://github.com/Quasiflo/launcher_icons/commit/b4013c9fa81a2bf1e9a897e4f7b6830bb490357c))
* svg sources with per-size rasterization opt-in ([bbba10c](https://github.com/Quasiflo/launcher_icons/commit/bbba10c75f631bfb63f95a9c13128aada5db3975))
* transparent adaptive icon background keyword (fluttercommunity/flutter_launcher_icons[#535](https://github.com/Quasiflo/launcher_icons/issues/535)) ([df556b1](https://github.com/Quasiflo/launcher_icons/commit/df556b1661978f9b056da9216cc9b74fdf59b171))
* try flutter_launcher_icons.yaml config file first and allow overriding configFile (fluttercommunity/flutter_launcher_icons[#60](https://github.com/Quasiflo/launcher_icons/issues/60)) ([6c1b3c0](https://github.com/Quasiflo/launcher_icons/commit/6c1b3c0f75b809a7cd1ec6cfda03e461b6bdfba4))
* web output_path for separate flavor roots (fluttercommunity/flutter_launcher_icons[#426](https://github.com/Quasiflo/launcher_icons/issues/426)) ([4f6920d](https://github.com/Quasiflo/launcher_icons/commit/4f6920d6c245cb26930cb38ce3ceaa37709c40bf))
* **web:** constants for web platform ([3c3ce79](https://github.com/Quasiflo/launcher_icons/commit/3c3ce79df7dc942df3c53065d528fa7a45e3a1d7))
* **web:** support for web icons ([a79ec01](https://github.com/Quasiflo/launcher_icons/commit/a79ec01cb4317e0f692d567aa28d9f3a07d3b70a))
* windows icon_filename override, 40/64 frames, upscale warning ([d2a93ca](https://github.com/Quasiflo/launcher_icons/commit/d2a93ca172f3b015ca60c357f4e052dcae5d43f9))
* **windows:** add support for windows closes fluttercommunity/flutter_launcher_icons[#380](https://github.com/Quasiflo/launcher_icons/issues/380) ([2444dfb](https://github.com/Quasiflo/launcher_icons/commit/2444dfbc34fa20a8c61c2f692ddf253ac6b36749))
* **windows:** generate multi-size .ico by default; deprecate windows.icon_size ([0778d78](https://github.com/Quasiflo/launcher_icons/commit/0778d78da741d87c2ada1908b8f20e92c90fb936))


### Bug Fixes

* accept any pubspec-declared asset path for linux ([b246b99](https://github.com/Quasiflo/launcher_icons/commit/b246b994953514273ce2fbf41c815a51b79b063a))
* **android:** minSdk not found closes fluttercommunity/flutter_launcher_icons[#384](https://github.com/Quasiflo/launcher_icons/issues/384) ([1f5f0f8](https://github.com/Quasiflo/launcher_icons/commit/1f5f0f8f746752aafd5daedfec886cd6c064dbe2))
* **android:** show blank icon if no adaptive icon set (fluttercommunity/flutter_launcher_icons[#601](https://github.com/Quasiflo/launcher_icons/issues/601)) ([5dc44fa](https://github.com/Quasiflo/launcher_icons/commit/5dc44fac65e82d03f893e2d83f7c809d18888c89))
* atomic pbxproj writes and loud warning for missing flavor keys (fluttercommunity/flutter_launcher_icons[#636](https://github.com/Quasiflo/launcher_icons/issues/636), fluttercommunity/flutter_launcher_icons[#341](https://github.com/Quasiflo/launcher_icons/issues/341)) ([f6d6af8](https://github.com/Quasiflo/launcher_icons/commit/f6d6af8a2093da757bb73050072dfd64403cc53a))
* avoid leaving stale ios & macos folders on failed runs ([f11f881](https://github.com/Quasiflo/launcher_icons/commit/f11f881593e6d4944fae7185fc53f38dfcceae07))
* bootstrap a missing macos icon set instead of crashing ([b1ead43](https://github.com/Quasiflo/launcher_icons/commit/b1ead43fb96bbb4eae136fbe4f4e7078709cd618))
* clean stale legacy icons and orphaned flavor catalogs ([ffce0f1](https://github.com/Quasiflo/launcher_icons/commit/ffce0f18900bed24a3ee64b353f0c4c0ec458e6b))
* clear stale adaptive icons when config is not adaptive (fluttercommunity/flutter_launcher_icons[#328](https://github.com/Quasiflo/launcher_icons/issues/328)) ([c934ba5](https://github.com/Quasiflo/launcher_icons/commit/c934ba5ccd25a9d35c396ee4ac2a1f9d1460e44d))
* code was always getting rid of trailing \n ([b64da82](https://github.com/Quasiflo/launcher_icons/commit/b64da824cddab2cd10aa6b421b867217fb4c6966))
* collect per-platform failures and exit non-zero ([442ce6f](https://github.com/Quasiflo/launcher_icons/commit/442ce6f029de8d460892ecdf6af14efa0399cecf))
* **config:** type error when invalid config is passed ([ef52d02](https://github.com/Quasiflo/launcher_icons/commit/ef52d0271a7a11f02adb888d3c18929415d0beef))
* correct background channels in iOS alpha blending (fluttercommunity/flutter_launcher_icons[#514](https://github.com/Quasiflo/launcher_icons/issues/514)) ([97e8acd](https://github.com/Quasiflo/launcher_icons/commit/97e8acd2551106d8716dd283a729727e7e227724))
* detect adaptive background image paths ([406b463](https://github.com/Quasiflo/launcher_icons/commit/406b463f473b28c7a6144319b42b1eb8542538b8))
* detect adaptive background image paths (fluttercommunity/flutter_launcher_icons[#670](https://github.com/Quasiflo/launcher_icons/issues/670)) ([406b463](https://github.com/Quasiflo/launcher_icons/commit/406b463f473b28c7a6144319b42b1eb8542538b8))
* don't add newline in Android manifest each time ([da64d63](https://github.com/Quasiflo/launcher_icons/commit/da64d636872cb7eb83be801ccf5297c1ca026d79))
* emit canonical plain monochrome XML at zero inset ([63fb69c](https://github.com/Quasiflo/launcher_icons/commit/63fb69c710ed3e389da1bf2d9a310cd638a26905))
* **example:** added example for pub.dev closes fluttercommunity/flutter_launcher_icons[#402](https://github.com/Quasiflo/launcher_icons/issues/402) ([199598e](https://github.com/Quasiflo/launcher_icons/commit/199598e32d81be57b8bdfa096ed0e34092715a47))
* explicit -f custom file bypasses flavor loop (fluttercommunity/flutter_launcher_icons[#426](https://github.com/Quasiflo/launcher_icons/issues/426)) ([cf5f3ac](https://github.com/Quasiflo/launcher_icons/commit/cf5f3ac236070b742a006c42a05a12ef6a2d4391))
* explicit -f flavor file runs only that flavor (fluttercommunity/flutter_launcher_icons[#215](https://github.com/Quasiflo/launcher_icons/issues/215)) ([a6cf3ff](https://github.com/Quasiflo/launcher_icons/commit/a6cf3ff6a7c6fdaac98cbabb2f793fbf52a66609))
* fail loudly when no platform is enabled ([f77c6eb](https://github.com/Quasiflo/launcher_icons/commit/f77c6eb78f1611f546e54b5d02911daf804a6f81))
* fixes the issue where the dark and tinted icons were placed in the wrong directory (fluttercommunity/flutter_launcher_icons[#597](https://github.com/Quasiflo/launcher_icons/issues/597)) ([8bd7f9a](https://github.com/Quasiflo/launcher_icons/commit/8bd7f9a608d7fe83b9ab0b2877389ff8293c041d))
* **generator:** fixed typo in a method ([61e3d6b](https://github.com/Quasiflo/launcher_icons/commit/61e3d6b0b2e0ade8f249eae1dbba19543650af1d))
* hand-holding error for removed windows.icon_size ([b021d4e](https://github.com/Quasiflo/launcher_icons/commit/b021d4e96d7756fa396fbb815a89f70370bc3736))
* hand-maintain version.dart, drop build_version ([3a61f75](https://github.com/Quasiflo/launcher_icons/commit/3a61f75c70935d32dfb6c130162b91426999ccf8))
* ignore commented minSdkVersion ([5cb7eb8](https://github.com/Quasiflo/launcher_icons/commit/5cb7eb8b6f6e76d2ad8b715689d151ea89e407f9))
* ignore commented minSdkVersion ([819b8fd](https://github.com/Quasiflo/launcher_icons/commit/819b8fdd4c112e23ab14bcfcb51559ea08586988))
* include 1x switcher sizes in modern iOS icon set (fluttercommunity/flutter_launcher_icons[#661](https://github.com/Quasiflo/launcher_icons/issues/661)) ([b252893](https://github.com/Quasiflo/launcher_icons/commit/b252893896977feb2ba556bdfb96f024581f866d))
* Incorrect version number shown ([d3f5d77](https://github.com/Quasiflo/launcher_icons/commit/d3f5d7742fb51c58e2fc40cf921bedd4f75c8f29))
* Incorrect version number shown ([ed733cd](https://github.com/Quasiflo/launcher_icons/commit/ed733cd858651db1d075f9f66c74734f6126abbd))
* json indentation ([e2d25e6](https://github.com/Quasiflo/launcher_icons/commit/e2d25e66a90fb9b5b31473f1f41662b3ad1d21a5))
* **lint:** filxed lint warnings for `public_member_api_docs` ([05a12e2](https://github.com/Quasiflo/launcher_icons/commit/05a12e2265589e2540c0be316c60034ccab2dd52))
* **lint:** filxed lint warnings for `require_trailing_commas` ([f815295](https://github.com/Quasiflo/launcher_icons/commit/f815295b16e081e04d23b7e6e8d568075dc087b3))
* **logging:** added verbose logging to platform failure ([860c84a](https://github.com/Quasiflo/launcher_icons/commit/860c84aee2a54112ad363627ac06c48324bc5a29))
* minSdk lookups tolerate missing files, fall back to default (fluttercommunity/flutter_launcher_icons[#644](https://github.com/Quasiflo/launcher_icons/issues/644)) ([23aae3e](https://github.com/Quasiflo/launcher_icons/commit/23aae3eecbe62097d9059fc56bbbba4f38070612))
* no longer printing creating icons message for unused platforms ([99a92be](https://github.com/Quasiflo/launcher_icons/commit/99a92be9e705fc66d968d086a74fae6bbcef1ffc))
* normalize bare hex colors written to colors.xml (fluttercommunity/flutter_launcher_icons[#673](https://github.com/Quasiflo/launcher_icons/issues/673)) ([4233061](https://github.com/Quasiflo/launcher_icons/commit/4233061dc8fb1d6527510685f652b3d1fc86af50))
* normalize flag semantics ([ae4ee3e](https://github.com/Quasiflo/launcher_icons/commit/ae4ee3ee5b61cd99ebf7c94e6a82ac1e5d147744))
* only update app-icon related configs (fluttercommunity/flutter_launcher_icons[#549](https://github.com/Quasiflo/launcher_icons/issues/549)) ([3ffe772](https://github.com/Quasiflo/launcher_icons/commit/3ffe77232ffaeb4af9a86a8fea118ce02ad57079))
* per-variant remove_alpha with unified hex parsing ([089e1e6](https://github.com/Quasiflo/launcher_icons/commit/089e1e6a496bfc93201bb931384bfcf512e40b07))
* rasterize each SVG source once per run ([63acc78](https://github.com/Quasiflo/launcher_icons/commit/63acc786e8603759236cff56c68d13d9d91329dd))
* remove dead hasPlatformConfig gate ([5d0de9d](https://github.com/Quasiflo/launcher_icons/commit/5d0de9dc66f765f90b63068eb28a26e3619a7cdc))
* remove dead minSdk apparatus ([dc61973](https://github.com/Quasiflo/launcher_icons/commit/dc61973f08504a7410d5fc90031f853d16d18a99))
* resolve renamed Xcode projects when editing pbxproj (fluttercommunity/flutter_launcher_icons[#543](https://github.com/Quasiflo/launcher_icons/issues/543)) ([75ac5c5](https://github.com/Quasiflo/launcher_icons/commit/75ac5c5908d68e7bf565c64d98f0caf6a6e5dd9c))
* route iOS through decodeImageFile with non-nullable return ([719702f](https://github.com/Quasiflo/launcher_icons/commit/719702f1f59ef46cd9699640d1a8cbcb42adab8d))
* sampled chroma scan for tinted validation ([7c6d642](https://github.com/Quasiflo/launcher_icons/commit/7c6d642f88bed42cf514ea011fff5d33a3775d20))
* satisfy strict-casts with explicit casts and typed flag accessors ([0b7e2f3](https://github.com/Quasiflo/launcher_icons/commit/0b7e2f3734eff389a9c2e6a0acc00a6512d84730))
* skip dark/tinted I/O entirely in iOS single-size mode ([8919b53](https://github.com/Quasiflo/launcher_icons/commit/8919b53e13514b41318d57544d3afc6ced46d4fe))
* stale generated template no longer shadows pubspec config (fluttercommunity/flutter_launcher_icons[#628](https://github.com/Quasiflo/launcher_icons/issues/628)) ([57696e2](https://github.com/Quasiflo/launcher_icons/commit/57696e2cd71d1a058a4c232c4076103d3d44a967))
* stop enforcing test pixel contracts on example fixtures ([5bd6c66](https://github.com/Quasiflo/launcher_icons/commit/5bd6c665ebe73e039eedd263c5301993625fb7aa))
* Success message printed on exception  (fluttercommunity/flutter_launcher_icons[#225](https://github.com/Quasiflo/launcher_icons/issues/225)) ([80beb55](https://github.com/Quasiflo/launcher_icons/commit/80beb5535be5a09eee744bb1c6a785775dc243ab))
* **template:** wrong attribute to remove alpha channel (fluttercommunity/flutter_launcher_icons[#586](https://github.com/Quasiflo/launcher_icons/issues/586)) ([3441875](https://github.com/Quasiflo/launcher_icons/commit/344187579840aa585527b31448ec47f39410e836))
* tests fails for the newly generated list (fluttercommunity/flutter_launcher_icons[#576](https://github.com/Quasiflo/launcher_icons/issues/576)) ([85d009d](https://github.com/Quasiflo/launcher_icons/commit/85d009dbfdce59a9d90f840894ef355171e2cda8))
* treat svg as image adaptive background, not colors.xml color ([cb53b7d](https://github.com/Quasiflo/launcher_icons/commit/cb53b7d36db0e1084adf2ad3c05f7bc01828b8a7))
* typo in readme (fluttercommunity/flutter_launcher_icons[#639](https://github.com/Quasiflo/launcher_icons/issues/639)) ([2b25c9c](https://github.com/Quasiflo/launcher_icons/commit/2b25c9cc48a2da221c0863175001b8cc19d8b383))
* typos ([e6fae79](https://github.com/Quasiflo/launcher_icons/commit/e6fae79330a59de54362b4f8d2557026d5c973ed))
* warn instead of crashing on corrupt macOS Contents.json ([3de6b38](https://github.com/Quasiflo/launcher_icons/commit/3de6b38b30f5931cd3575b9e7feb3121279ec03b))
* web index.html updater and opaque apple-touch-icon ([acc2f66](https://github.com/Quasiflo/launcher_icons/commit/acc2f66e0e8c770818c9a75076dcfc44ce4d0aa0))
* wire flavor configs that share the base xcconfig ([a52fbbe](https://github.com/Quasiflo/launcher_icons/commit/a52fbbe709d392b115ff2ea743c491377ef3ea66))
* wire macOS flavor catalogs into project.pbxproj ([ce7384d](https://github.com/Quasiflo/launcher_icons/commit/ce7384da508547b1422fa19ebd061beaf5dcac48))
* write custom icon_name PNGs to their own catalog ([0173c21](https://github.com/Quasiflo/launcher_icons/commit/0173c21a7ee0d07cc33a83359bdf90eb50578a0f))
* wrong PR mentioned in changelog (fluttercommunity/flutter_launcher_icons[#584](https://github.com/Quasiflo/launcher_icons/issues/584)) ([0dcac54](https://github.com/Quasiflo/launcher_icons/commit/0dcac54ce0de75c476af42cc17a28c9114be8863))


### Miscellaneous Chores

* rebrand flutter_launcher_icons to launcher_icons ([7150da6](https://github.com/Quasiflo/launcher_icons/commit/7150da6b41f4e090ee77e89aa89ca89bf43159dd))
* remove deprecated windows.icon_size, flutter_icons key and main shim ([1b763c0](https://github.com/Quasiflo/launcher_icons/commit/1b763c08ae2dea482cb6cb40179b3d37af51898a))

## 0.14.4 (10th June 2025)

- Removed rules which no longer exist from analysis_options [#598](https://github.com/fluttercommunity/flutter_launcher_icons/issues/598)
- Fix template generated within thegenerate command [#642](https://github.com/fluttercommunity/flutter_launcher_icons/issues/642)
- Standardize on async I/O and waiting for work to complete [#646](https://github.com/fluttercommunity/flutter_launcher_icons/issues/646)

## 0.14.3 (17th January 2025)

- Android: Avoids creating mipmap file used by adaptive and monochrome icons if no config exist for both [#601](https://github.com/fluttercommunity/flutter_launcher_icons/pull/601)

## 0.14.2 (5th December 2024)

- iOS: Fixed issue where dark and tinted icons were placed into the wrong directory [#597](https://github.com/fluttercommunity/flutter_launcher_icons/pull/597)

## 0.14.1 (24th September 2024)

- Fixed README

## 0.14.0 (21st September 2024)

- Android: Support for monochrome icons [#497](https://github.com/fluttercommunity/flutter_launcher_icons/pull/497)

**Before**

<img src="https://github.com/user-attachments/assets/ce16287d-1394-4404-b056-8308f0a69f07" width=40%>

**Now**

<img src="https://github.com/user-attachments/assets/a420fefd-28b0-4eb9-8fd0-2e03068d3d83" width=40%>

- Android: Ability to set inset for adaptive icon foreground and monochrome icon [#563](https://github.com/fluttercommunity/flutter_launcher_icons/pull/563)
- iOS: Dark and Tinted icons for iOS 18+ [#569](https://github.com/fluttercommunity/flutter_launcher_icons/pull/569)

## 0.13.1 (15th April 2023)

- Can now use `flutter_launcher_icons` instead of `flutter_icons` [#478](https://github.com/fluttercommunity/flutter_launcher_icons/pull/478)
- Can use command `flutter pub run flutter_launcher_icons:generate` to automatically generate config file [#475](https://github.com/fluttercommunity/flutter_launcher_icons/pull/475)


## 0.13.0 (7th April 2023)

- Fix remove alpha for iOS [#464](https://github.com/fluttercommunity/flutter_launcher_icons/pull/464)
- Updating code style [#472](https://github.com/fluttercommunity/flutter_launcher_icons/pull/472)
- Updated out of bounds dependency [#473](https://github.com/fluttercommunity/flutter_launcher_icons/pull/473)

## 0.12.0 (24th February 2023)

- Updated image package and other packages [#447](https://github.com/fluttercommunity/flutter_launcher_icons/pull/447)

## 0.11.0 (27th September 2022)
    
- Support for Macos Icons [#407](https://github.com/fluttercommunity/flutter_launcher_icons/pull/407)
- Cli-improvement [#400](https://github.com/fluttercommunity/flutter_launcher_icons/pull/400)
- Add `repository` and `issue_tracker` [#411](https://github.com/fluttercommunity/flutter_launcher_icons/pull/411) (thanks to [@patelpathik](https://github.com/patelpathik))
- Fix indent in web/manifest.json [#407](https://github.com/fluttercommunity/flutter_launcher_icons/pull/407)
- Fix the icons 50 and 57 in `contents.json` [#412](https://github.com/fluttercommunity/flutter_launcher_icons/pull/412) (thanks to [@adnanjpg](https://github.com/adnanjpg))
- Fix typos [#405](https://github.com/fluttercommunity/flutter_launcher_icons/pull/405) (thanks to [@edwardmp](https://github.com/edwardmp))
- Added newline to EOF [#325](https://github.com/fluttercommunity/flutter_launcher_icons/pull/325) (thanks to [@sandersaelmans](https://github.com/sandersaelmans))

## 0.10.0 (2nd August 2022)

- Support for Web Icons [#374](https://github.com/fluttercommunity/flutter_launcher_icons/pull/374)
- Support for Windows Icons [#382](https://github.com/fluttercommunity/flutter_launcher_icons/pull/382)
- Added missing IOS icon sizes [#298](https://github.com/fluttercommunity/flutter_launcher_icons/pull/298)
- Added `min_sdk_android` option [#392](https://github.com/fluttercommunity/flutter_launcher_icons/pull/392)
- Added documentation for `remove_alpha_ios` [#392](https://github.com/fluttercommunity/flutter_launcher_icons/pull/392)
- Fixed issue with loading config from `pubspec.yaml` [#398](https://github.com/fluttercommunity/flutter_launcher_icons/pull/398) (thanks to [@p-mazhnik](https://github.com/p-mazhnik))

## 0.9.3 (6th June 2022)

- Fixes to make sure it works for Flutter v2.8 (thanks to @RatakondalaArun)
- Fixed issue with incorrect version being shown

## 0.9.2 (22nd August 2021)

- Fixed issue where success message printed even when exception occured (thanks to @happy-san)

## 0.9.1 (25th July 2021)

- Upgrade args dependency to ^2.1.1 (thanks to @PiN73 and @comlaterra)
- Upgraded `image` and `test` dependencies

## 0.9.0 (28th Feb 2021)

- Null-safety support added (thanks to @SteveAlexander)
- Added option to remove alpha channel for iOS icons (thanks to @SimonIT)

## 0.8.1 (2nd Oct 2020)

- Fixed flavor support on windows (@slightfoot)

## 0.8.0 (12th Sept 2020)

- Added flavours support (thanks to @sestegra & @jorgecoca)
- Removed unassigned iOS icons (thanks to @melvinsalas)
- Fixing formatting (thanks to @mreichelt)

## 0.7.5 (24th April 2020)

- Fixed issue where new lines were added to Android manifest (thanks to @mreichelt)
- Improvements to code quality and general tidying up (thanks to @connectety)
- Fixed Android example project not running (needed to be migrated to AndroidX)

## 0.7.4 (28th Oct 2019)

- Worked on suggestions from [pub.dev](https://pub.dev/packages/flutter_launcher_icons#-analysis-tab-)

## 0.7.3 (3rd Sept 2019)

- Lot of refactoring and improving code quality (thanks to @connectety)
- Added correct App Store icon settings (thanks to @richgoldmd)

## 0.7.2 (25th May 2019)

- Reverted back using old interpolation method

## 0.7.1 (24th May 2019)

- Fixed issue with image dependency not working on latest version of Flutter (thanks to @sboutet06)
- Fixed iOS icon sizes which were incorrect (thanks to @sestegra)
- Removed dart_config git dependency and replaced with yaml dependency
- Refactoring of code

## 0.7.0 (22nd November 2018)

- Now ensuring that the Android file name is valid - An error will be thrown if it doesn't meet the criteria
- Fixed issue where there was a git diff when there was no change
- Fixed issue where iOS icon would be generated when it shouldn't be
- Added support for drawables to be used for adaptive icon backgrounds
- Added support for Flutter Launcher Icons to be able to run with it's own config file (no longer necessary to add to pubspec.yaml)

## 0.6.1 (26th August 2018)

- Upgraded test package
- Due to issue with dart_config not working with Dart 2.1.0, now using forked version of dart_config which contains fixes from both @v3rm0n and @SPodjasek

## 0.6.0 (8th August 2018)

- Moved the package to [Flutter Community](https://github.com/fluttercommunity/community)

## 0.5.2 (19th June 2018)

- Previous release didn't fix adaptive icons, just prevented the error message from appearing. This should hopefully fix it!

## 0.5.1 (18th June 2018)

- Fix for adaptive icons

## 0.5.0 (12th June 2018)

- [Android] Support for adaptive icons added (Suggestion #23)

## 0.4.0 (9th June 2018)

- Now possible to generate icons for each platform with different image paths (one for iOS icon and a separate one for Android)

## 0.3.3 (28th May 2018)

- Upgraded dart image package dependency to 2.0.0 (issue #26)

## 0.3.2 (2nd May 2018)

- Bug fixing

## 0.3.1 (1st May 2018)

- Bug fixing

## 0.3.0 (1st May 2018)

- Fixed issue where icons produced weren't the correct size (Due to images not with a 1:1 aspect r    ation)
- Improved quality of smaller icons produced (Thanks to PR #17 - Thank you!)
- Updated console printed messages to keep them consistent
- Added example folder to GitHub project

## 0.2.1 (25th April 2018)

- Added extra iOS icon size (1024x1024)
- Fixed iOS default icon name (Thanks to PR #15 - Thank you!)
- Fixed issue #10 where creation of the icons was failing due to the target folder not existing

## 0.2.0 (18th January 2018)

- Ability to create new launcher icons without replacing the old ones added (#6)
- Fixed issue with launcher icons for iOS not correctly being set

## 0.0.5

- Quick Fix on if statement

## 0.0.4

- Fixing strong mode error

## 0.0.3

- Adding flutter as a dependency so its listed as a flutter package.

## 0.0.2

- Fix Doc typo

## 0.0.1

- Initial version, Resizes Icon to Android sizes only.
