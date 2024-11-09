# VLCLI - Internal API CLI Tool

A command-line interface tool for interacting with internal APIs. Built with Zig for type safety and performance.

## Installation

### Using the Install Script

```bash
# Clone the repository
git clone git@github.com:youorg/vlcli.git
cd vlcli

# Run the install script
./install.sh
```

The install script will:

1. Validate your environment configuration
2. Build the project with optimizations
3. Create appropriate symlinks
4. Guide you through any necessary PATH configurations

### Manual Installation

1. Clone the repository

```bash
git clone git@github.com:youorg/vlcli.git
cd vlcli
```

2. Set up environment variables (either in shell or .env file)

```bash
# Local environment
export LOCAL_BASE_URL=http://localhost:3000
export LOCAL_AUTH_HEADER_NAME=X-Auth-Token
export LOCAL_AUTH_HEADER_VALUE=local_dev_key_here
# Production environment
export PROD_BASE_URL=https://app.getvoiceline.com
export PROD_AUTH_HEADER_NAME=Voiceline-Search-Auth
export PROD_AUTH_HEADER_VALUE=your_prod_key_here
```

3. Build the project

```bash
zig build -Doptimize=ReleaseSafe
```

4. Create a global symlink (choose one):

```bash
# Option 1: Add to /usr/local/bin (requires sudo)
sudo ln -s "$(pwd)/zig-out/bin/vlcli" /usr/local/bin/vlcli

# Option 2: Add to ~/bin (user-specific)
mkdir -p ~/bin
ln -s "$(pwd)/zig-out/bin/vlcli" ~/bin/vlcli
# Add to your .bashrc or .zshrc:
export PATH="$HOME/bin:$PATH"
```

## Configuration

### Environment Variables

You can configure the environment variables either through:

1. A `.env` file (recommended for development)
2. Shell environment variables (recommended for production)

Example `.env` file:

```env
# Local environment
LOCAL_BASE_URL=http://localhost:3000
LOCAL_AUTH_HEADER_NAME=X-Auth-Token
LOCAL_AUTH_HEADER_VALUE=local_dev_key_here
# Production environment
PROD_BASE_URL=https://app.getvoiceline.com
PROD_AUTH_HEADER_NAME=Voiceline-Search-Auth
PROD_AUTH_HEADER_VALUE=your_prod_key_here
```

### Endpoint Configuration (endpoint_config.zig)

```zig
pub const endpoints = struct {
    pub const surgery = EndpointMap{
        .path = "/api/test/surgery",
        .params = &[_]ParamDefinition{
            .{ .name = "id" },
        },
    };
    pub const related_contacts = EndpointMap{
        .path = "/search_special/related_contacts_v2",
        .params = &[_]ParamDefinition{
            .{ .name = "wsp_id" },
            .{ .name = "externalId" },
            .{ .name = "tagType" },
        },
    };
};
```

## Usage Examples

### Basic Usage

```bash
# Local environment (default)
vlcli surgery 44715

# Production environment
vlcli -p surgery 44715

# Multiple parameters
vlcli related_contacts 123 456 customer
```

### With Optional Parameters

```bash
# Command with optional filter
vlcli search_patient 44715 active

# Same command without optional parameter
vlcli search_patient 44715
```

### Help System

```bash
# Show general help
vlcli -h

# Available commands and their parameters will be shown:
Available commands:
  surgery <id>
  related_contacts <wsp_id> <externalId> <tagType>
  search_patient <id> [filter]
```

## Development

### Project Structure

```
vlcli/
├── src/
│   ├── main.zig           # Main CLI logic
│   ├── env_config.zig     # Environment configuration
│   └── endpoint_config.zig # Endpoint definitions
├── .env                   # Environment variables (gitignored)
├── .env.example          # Template for environment variables
├── install.sh            # Installation script
└── README.md             # This file
```

### Building for Development

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseSafe

# Run tests
zig build test
```

### Environment Handling

The CLI now supports runtime environment switching:

- Environment configurations are baked into the binary at build time
- Switch between environments using the `-p` flag
- No need to rebuild for different environments
- Environment variables must be present at build time

## Security Notes

- Keep `.env` file secure and gitignored
- Use environment variables for sensitive data
- Store production auth tokens securely
- Consider implementing rate limiting for production endpoints
- Avoid committing any files containing sensitive information
- The binary contains both environments' configurations, keep it secure

## Error Handling

The CLI provides clear error messages:

```bash
# Missing required parameter
$ vlcli related_contacts 123
Error: Command 'related_contacts' requires 3 parameters, but got 1
Usage: vlcli related_contacts <wsp_id> <externalId> <tagType>

# Invalid environment configuration
Error: Missing required environment variable: PROD_AUTH_HEADER_NAME

# Unknown command
Error: Unknown command 'unknown'
Available commands:
  surgery <id>
  related_contacts <wsp_id> <externalId> <tagType>
  ...
```
