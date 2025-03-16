#!/bin/sh

echo "Setting up post-merge hooks"
echo "#!/bin/sh" > .git/hooks/post-merge
echo "java -jar ./automation/InstanceSync.jar" >> .git/hooks/post-merge
chmod +x .git/hooks/post-merge

echo "Setting up pre-commit hooks"
echo "#!/bin/sh" > .git/hooks/pre-commit
echo "pwsh -ExecutionPolicy Bypass -Command '.\automation\sanitise-instance.ps1'" >> .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Done setting up hooks"
echo "Running InstanceSync"

java -jar ./automation/InstanceSync.jar