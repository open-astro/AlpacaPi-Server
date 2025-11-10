# Contributing to AlpacaPi

Thank you for your interest in contributing to AlpacaPi! This document provides guidelines and information for contributors.

## How to Contribute

1. **Fork the repository** on GitHub
2. **Create a branch** for your changes (`git checkout -b feature/your-feature-name`)
3. **Make your changes** following the coding standards below
4. **Test your changes** to ensure they work correctly
5. **Commit your changes** with clear, descriptive commit messages
6. **Push to your fork** (`git push origin feature/your-feature-name`)
7. **Create a Pull Request** on GitHub

## Code Formatting Rules

**CRITICAL RULE: USE TABS (not spaces) for all C/C++ source files**

The developer is very particular about using tabs for indentation. All indentation in `.c`, `.cpp`, `.h`, and `.hpp` files MUST use tabs.

### Formatting Standards

Based on analysis of the actual codebase, the following formatting rules apply:

- ✓ **TABS for indentation** (not spaces) - CRITICAL
- ✓ **Tab width**: 8 spaces equivalent
- ✓ **Opening braces on same line**
- ✓ **No column limit** (allow long lines)
- ✓ **Trailing comments aligned**
- ✓ **Spaces around operators** in conditions
- ✓ **No spaces in parentheses**
- ✓ **Pointer alignment**: Left (`*ptr`, not `ptr*`)

### Formatting Examples

Some formatting patterns in the codebase use tab-based alignment for assignments (multiple tabs for visual alignment). Examples:

```c
// Assignment alignment: uses tabs for alignment
variable	=	value;

// Return statements: with parentheses
return(value);

// For loops: no spaces around = in init
for (iii=0; iii<max; iii++)
```

**NOTE**: Some formatting patterns may need manual adjustment to match the exact visual style of existing code. The `.editorconfig` ensures tabs are used for indentation, which is the most critical requirement.

## Configuration Files

### .editorconfig

- Configuration file read by text editors (VS Code, Vim, Emacs, etc.)
- Tells editors to use TABS when editing files
- Does NOT affect compilation - purely for editor behavior
- Automatically applied when you open files in supported editors

### .clang-format

- Configuration file for the clang-format code formatting tool
- Used when you manually run: `clang-format -i file.cpp`
- Does NOT affect compilation - it's a separate formatting tool
- Must be run manually or via scripts/IDE integration

**IMPORTANT**: Neither file affects the compiler (gcc/clang) or Makefile! The compiler treats tabs and spaces identically - these files are ONLY for maintaining consistent code formatting and editor behavior.

## Formatting Code

### Manual Formatting

To format code manually:
```bash
clang-format -i *.cpp *.h
clang-format -i src/*.cpp src/*.h
```

To check formatting without changing files:
```bash
clang-format --dry-run --Werror *.cpp *.h
```

To format a single file:
```bash
clang-format -i filename.cpp
```

## Editor Setup

### Supported Editors (with plugins/extensions)

- **VS Code**: Install "EditorConfig for VS Code" extension
- **Vim/Neovim**: Install editorconfig-vim plugin
- **Emacs**: Install editorconfig-emacs package
- **Sublime Text**: Install EditorConfig plugin
- **JetBrains IDEs** (IntelliJ, CLion): Built-in support (enable in settings)
- **Atom**: Install editorconfig package

### Checking if Your Editor Supports .editorconfig

1. Open a `.c` or `.cpp` file
2. Press Tab - if it inserts a TAB character (not spaces), it's working
3. Check your editor's settings for "EditorConfig" or "indent style"

### If Your Editor Doesn't Support .editorconfig

- Manually configure your editor to use TABS (not spaces) for `.c`/`.cpp`/`.h` files
- Set tab width to 8
- The `.clang-format` file can still be used via command line

### Using clang-format

`.clang-format` works regardless of editor:
- You can run it from command line: `clang-format -i file.cpp`
- Many editors can integrate clang-format (check your editor's plugin/extensions)
- Some editors can format on save using clang-format

Once configured, editors will automatically use tabs when editing `.c`/`.cpp`/`.h` files.

## Code Style Guidelines

- Follow the existing code style in the project
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and reasonably sized
- Test your changes before submitting

## Testing

Before submitting a pull request, please:
- Test your changes on the target platform(s)
- Ensure existing functionality still works
- Add tests if you're adding new features

## Questions?

If you have questions about contributing, please:
- Open an issue on GitHub
- Contact the maintainer: msproul@skychariot.com

Thank you for contributing to AlpacaPi!

