$ErrorActionPreference = 'Stop'
$flutterArgs = @(ConvertFrom-Json $env:BIDVIBE_ANDROID_FLUTTER_ARGS)
& $env:BIDVIBE_ANDROID_FLUTTER @flutterArgs
exit $LASTEXITCODE
