#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
task_test_dir=$(mktemp -d /tmp/shlyapa-tests.XXXXXX)
xcrun swiftc Domain/GameDomain.swift Domain/BuiltinPacks.swift Tests/DomainTests.swift -o "$task_test_dir/domain"
"$task_test_dir/domain"
xcrun swiftc -target arm64-apple-macosx14.0 Domain/GameDomain.swift Data/Repositories.swift Tests/StorageTests.swift -o "$task_test_dir/storage"
"$task_test_dir/storage"

xcrun swiftc -target arm64-apple-macosx14.0 Domain/GameDomain.swift Domain/BuiltinPacks.swift Data/Repositories.swift Presentation/AppViewModel.swift Tests/ViewModelTests.swift -o "$task_test_dir/viewmodel"
"$task_test_dir/viewmodel"
