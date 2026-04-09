@echo off
REM 自動テスト実行バッチファイル
REM 使用方法: run_autotest.bat [Godotの実行ファイルパス]

SET GODOT_PATH=%1
SET PROJECT_PATH=%~dp0

IF "%GODOT_PATH%"=="" (
    echo エラー: Godotの実行ファイルパスを指定してください
    echo 使用例: run_autotest.bat "C:\Godot\Godot.exe"
    exit /b 1
)

echo Godotパス: %GODOT_PATH%
echo プロジェクトパス: %PROJECT_PATH%
echo.
echo 自動テストを実行中...
echo.

"%GODOT_PATH%" --path "%PROJECT_PATH%" --headless --autotest res://scenes/Main.tscn

echo.
echo テスト完了。結果は AppData\Roaming\Godot\app_userdata\dungeon-board-game\autotest_results.json に保存されました。
pause
