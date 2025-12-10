# Continue IDE Integration

## Purpose
The Continue IDE integration provides configuration for the Continue VS Code extension, an AI coding assistant that supports multiple LLM providers including Gemini, OpenAI, and local Ollama models.

## Requirements

### Requirement: Tag-Based Configuration
Continue configuration SHALL only be applied on machines with both `dev` and `ai` tags.

#### Scenario: Both dev and ai tags present
- **WHEN** chezmoi applies configuration with both `dev` and `ai` tags selected
- **THEN** the Continue configuration file SHALL be created at `~/.continue/config.yaml`

#### Scenario: Missing required tags
- **WHEN** either the `dev` or `ai` tag is not selected
- **THEN** the Continue configuration file SHALL NOT be created
- **AND** SHALL be skipped via template conditional

### Requirement: Configuration File Location
The Continue configuration SHALL be placed in the user's home directory.

#### Scenario: Config file path
- **WHEN** the configuration is applied
- **THEN** the file SHALL be created at `~/.continue/config.yaml`
- **AND** SHALL use the dot_continue directory structure in the chezmoi source

### Requirement: Multi-Provider Model Support
The configuration SHALL support multiple LLM providers for flexibility and fallback options.

#### Scenario: Cloud providers with KeePassXC
- **WHEN** `has_keepassxc_db` is true
- **THEN** the configuration SHALL include:
  - Gemini 2.0 Flash model with API key from KeePassXC entry "Gemini"
  - GPT-5 model with API key from KeePassXC entry "OpenAI platform" attribute "CodeGPT_key"

#### Scenario: Local Ollama provider
- **WHEN** the configuration is applied
- **THEN** it SHALL always include an Ollama provider with "AUTODETECT" model
- **AND** SHALL use "test" as the API key (not required for local Ollama)

### Requirement: KeePassXC Integration for API Keys
Cloud provider API keys SHALL be retrieved from KeePassXC at template execution time.

#### Scenario: Gemini API key retrieval
- **WHEN** KeePassXC database is available
- **THEN** the Gemini API key SHALL be retrieved using `keepassxcAttribute "Gemini" "API Key"`

#### Scenario: OpenAI API key retrieval
- **WHEN** KeePassXC database is available
- **THEN** the OpenAI API key SHALL be retrieved using `keepassxcAttribute "OpenAI platform" "CodeGPT_key"`

### Requirement: Configuration Schema Compliance
The configuration SHALL follow the Continue extension's v1 schema format.

#### Scenario: Schema version
- **WHEN** the configuration file is generated
- **THEN** it SHALL specify `schema: v1`
- **AND** SHALL include required fields: name, version, models

### Requirement: Model Configuration Structure
Each model configuration SHALL include provider, model name, and API key.

#### Scenario: Gemini model configuration
- **WHEN** Gemini is configured
- **THEN** it SHALL specify:
  - name: "Gemini 2.0 Flash"
  - provider: "gemini"
  - model: "gemini-2.0-flash"
  - apiKey: (from KeePassXC)

#### Scenario: OpenAI model configuration
- **WHEN** OpenAI is configured
- **THEN** it SHALL specify:
  - name: "GPT-5"
  - provider: "openai"
  - model: "gpt-5"
  - apiKey: (from KeePassXC)

#### Scenario: Ollama model configuration
- **WHEN** Ollama is configured
- **THEN** it SHALL specify:
  - name: "Autodetect"
  - provider: "ollama"
  - model: "AUTODETECT"
  - apiKey: "test"

### Requirement: Graceful Degradation
The configuration SHALL work even when KeePassXC is unavailable by providing local Ollama option.

#### Scenario: KeePassXC unavailable
- **WHEN** `has_keepassxc_db` is false
- **THEN** only the Ollama provider SHALL be configured
- **AND** cloud providers SHALL be omitted
- **AND** the user can still use local models

## Design Decisions

### Multi-Provider Strategy
Supporting multiple LLM providers provides:
- Flexibility to choose the best model for each task
- Fallback options when one provider is unavailable
- Cost optimization by using local models when possible
- Access to latest model capabilities from different providers

### KeePassXC for API Keys
Storing API keys in KeePassXC ensures:
- No secrets committed to git repository
- Secure credential storage
- Easy credential rotation by updating KeePassXC entries
- Consistent secret management pattern with other services

### Local Ollama Support
Always including Ollama provider enables:
- Offline AI coding assistance
- Zero cost option for experimentation
- Privacy-focused workflow with local models
- Fallback when cloud services are unavailable

### Tag Requirements (dev + ai)
Requiring both tags ensures:
- Only developers who use AI tools get the configuration
- Minimal installations don't include unnecessary AI configs
- Clear opt-in for AI-powered development tools
- Consistent pattern with other AI tool installations

### Autodetect Model for Ollama
Using AUTODETECT for Ollama allows:
- Automatic selection of available local models
- No need to hardcode specific model names
- Flexibility to switch models without config changes
- Simpler configuration maintenance