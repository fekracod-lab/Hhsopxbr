$path = "lib\pages\teachers_directory_page.dart"
$content = Get-Content -Path $path -Raw -Encoding UTF8
$content = $content.Replace([char]160, [char]32)
Set-Content -Path $path -Value $content -Encoding UTF8
Write-Output "Fixed non-breaking spaces in $path"
