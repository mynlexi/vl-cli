# VLCLI - Internal API CLI Tool

A command-line interface tool for interacting with internal APIs. Built with Zig for type safety and performance.

## Installation

1. Clone the repository

```bash
git clone git@github.com:youorg/vlcli.git
cd vlcli
```

2. Copy configuration templates

```bash
cp env_config.zig.template env_config.zig
cp endpoint_config.zig.template endpoint_config.zig
cp .env.example .env
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
# export PATH="$HOME/bin:$PATH"
```

## Configuration

### Environment Variables (.env)

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

## Adding New Endpoints

1. Open `endpoint_config.zig`
2. Add your new endpoint following the pattern:

```zig
pub const your_endpoint = EndpointMap{
    .path = "/api/your/path",
    .params = &[_]ParamDefinition{
        .{ .name = "required_param" },
        .{ .name = "optional_param", .required = false },
    },
};
```

## Error Handling

The CLI provides clear error messages:

```bash
# Missing required parameter
$ vlcli related_contacts 123
Error: Command 'related_contacts' requires 3 parameters, but got 1

Usage: vlcli related_contacts <wsp_id> <externalId> <tagType>

# Missing environment variable
Error: Missing environment variable: PROD_AUTH_HEADER_NAME

# Unknown command
Error: Unknown command 'unknown'

Available commands:
  surgery <id>
  related_contacts <wsp_id> <externalId> <tagType>
  ...
```

## Development

### Project Structure

```
vlcli/
├── src/
│   ├── main.zig         # Main CLI logic
│   ├── env_config.zig   # Environment configuration (gitignored)
│   └── endpoint_config.zig  # Endpoint definitions (gitignored)
├── .env                 # Environment variables (gitignored)
├── .env.example        # Template for environment variables
└── README.md           # This file
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

## Security Notes

- Never commit `env_config.zig`, `endpoint_config.zig`, or `.env`
- Always use environment variables for sensitive data
- Production auth tokens should be kept secure
- Consider implementing rate limiting for production endpoints
