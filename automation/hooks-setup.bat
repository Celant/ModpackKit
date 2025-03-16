@echo off

echo Setting up post-merge hooks
type NUL > .git/hooks/post-merge
echo #!/bin/sh > .git/hooks/post-merge
echo java -jar ./automation/InstanceSync.jar >> .git/hooks/post-merge

echo Setting up pre-commit hooks
type NUL > .git/hooks/pre-commit
echo #!/bin/sh > .git/hooks/pre-commit
echo c:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass -Command '.\automation\format-instance.ps1' >> .git/hooks/pre-commit

echo Done setting up hooks
echo Running InstanceSync

java -jar ./automation/InstanceSync.jar