$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

$target = Join-Path $RepoRoot "third_party\3D-Speaker"
$py = if (Test-Path $VenvPython) { $VenvPython } else { Join-Path $RepoRoot "ZX\Scripts\python.exe" }

function Ensure-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "需要 Git: https://git-scm.com"
    }
}

Ensure-Git
$parent = Split-Path $target -Parent
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

if (-not (Test-Path (Join-Path $target "speakerlab"))) {
    Write-Host "克隆 3D-Speaker -> $target"
    git clone --depth 1 https://github.com/modelscope/3D-Speaker.git $target
}
else {
    Write-Host "3D-Speaker 已存在: $target"
}

Write-Host "安装 PyTorch (CPU) 与 ModelScope 依赖..."
& $py -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
& $py -m pip install modelscope scipy scikit-learn soundfile tqdm pyyaml addict Pillow `
    -i https://pypi.tuna.tsinghua.edu.cn/simple

Write-Host ""
Write-Host 'Done. CAM++ model will download from ModelScope on first diarization run.'
Write-Host 'Optional .env: DIARIZATION_MODEL_CACHE=D:/01_Dev/Environment/ModelScopeCache'
