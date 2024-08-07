local State = require("parrot.state")
local mock = require("luassert.mock")
local stub = require("luassert.stub")

describe("State", function()
  local function setup_mocks()
    stub(vim.fn, "filereadable")
    stub(require("parrot.file_utils"), "file_to_table")
    stub(require("parrot.file_utils"), "table_to_file")
  end

  local function teardown_mocks()
    vim.fn.filereadable:revert()
    require("parrot.file_utils").file_to_table:revert()
    require("parrot.file_utils").table_to_file:revert()
  end

  describe("new", function()
    before_each(setup_mocks)
    after_each(teardown_mocks)

    it("should create a new state instance with existing file", function()
      vim.fn.filereadable.returns(1)
      require("parrot.file_utils").file_to_table.returns({
        ollama = {
          command_agent = "Gemma-7B",
          chat_agent = "Gemma-7B",
        },
        mistral = {
          command_agent = "Mistral-Medium",
          chat_agent = "Open-Mixtral-8x7B",
        },
        pplx = {
          command_agent = "Llama3-70B-Instruct",
          chat_agent = "Llama3-Sonar-Large-32k-Chat",
        },
        anthropic = {
          command_agent = "Claude-3.5-Sonnet",
          chat_agent = "Claude-3-Haiku-Chat",
        },
        openai = {
          command_agent = "CodeGPT4o",
          chat_agent = "ChatGPT4",
        },
        provider = "anthropic",
      })

      local state = State:new("/tmp")

      assert.are.same("/tmp/state.json", state.state_file)
      assert.are.same({
        ollama = {
          command_agent = "Gemma-7B",
          chat_agent = "Gemma-7B",
        },
        mistral = {
          command_agent = "Mistral-Medium",
          chat_agent = "Open-Mixtral-8x7B",
        },
        pplx = {
          command_agent = "Llama3-70B-Instruct",
          chat_agent = "Llama3-Sonar-Large-32k-Chat",
        },
        anthropic = {
          command_agent = "Claude-3.5-Sonnet",
          chat_agent = "Claude-3-Haiku-Chat",
        },
        openai = {
          command_agent = "CodeGPT4o",
          chat_agent = "ChatGPT4",
        },
        provider = "anthropic",
      }, state.file_state)
      assert.are.same({}, state._state)
    end)

    it("should create a new state instance without existing file", function()
      vim.fn.filereadable.returns(0)

      local state = State:new("/tmp")

      assert.are.same("/tmp/state.json", state.state_file)
      assert.are.same({}, state.file_state)
      assert.are.same({}, state._state)
    end)
  end)

  describe("init_file_state", function()
    it("should initialize file state for each provider", function()
      local state = State:new("/tmp")
      local providers = { "ollama", "mistral", "pplx", "anthropic", "openai" }

      state:init_file_state(providers)

      assert.are.same({
        ollama = { chat_agent = nil, command_agent = nil },
        mistral = { chat_agent = nil, command_agent = nil },
        pplx = { chat_agent = nil, command_agent = nil },
        anthropic = { chat_agent = nil, command_agent = nil },
        openai = { chat_agent = nil, command_agent = nil },
      }, state.file_state)
    end)
  end)

  describe("init_provider_state", function()
    it("should initialize provider state", function()
      local state = State:new("/tmp")

      state:init_provider_state("ollama")

      assert.are.same({ ollama = { chat_agent = nil, command_agent = nil } }, state._state)
    end)
  end)

  describe("load_agents", function()
    it("should load chat agent from file state if valid", function()
      local state = State:new("/tmp")
      state.file_state = { ollama = { chat_agent = "Gemma-7B" } }
      state._state = { ollama = { chat_agent = nil } }
      local available_agents = { ollama = { chat = { "Gemma-7B", "Llama2-7B" } } }

      state:load_agents("ollama", "chat_agent", available_agents)

      assert.are.same("Gemma-7B", state._state.ollama.chat_agent)
    end)

    it("should load default chat agent if file state is invalid", function()
      local state = State:new("/tmp")
      state.file_state = { ollama = { chat_agent = "invalid-model" } }
      state._state = { ollama = { chat_agent = nil } }
      local available_agents = { ollama = { chat = { "Gemma-7B", "Llama2-7B" } } }

      state:load_agents("ollama", "chat_agent", available_agents)

      assert.are.same("Gemma-7B", state._state.ollama.chat_agent)
    end)
  end)

  describe("refresh", function()
    before_each(setup_mocks)
    after_each(teardown_mocks)

    it("should refresh state with available providers and agents", function()
      local state = State:new("/tmp")
      local available_providers = { "ollama", "mistral", "pplx", "anthropic", "openai" }
      local available_agents = {
        ollama = { chat = { "Gemma-7B" }, command = { "Gemma-7B" } },
        mistral = { chat = { "Open-Mixtral-8x7B" }, command = { "Mistral-Medium" } },
        pplx = { chat = { "Llama3-Sonar-Large-32k-Chat" }, command = { "Llama3-70B-Instruct" } },
        anthropic = { chat = { "Claude-3-Haiku-Chat" }, command = { "Claude-3.5-Sonnet" } },
        openai = { chat = { "ChatGPT4" }, command = { "CodeGPT4o" } },
      }

      state:refresh(available_providers, available_agents)

      assert.are.same({
        ollama = { chat_agent = "Gemma-7B", command_agent = "Gemma-7B" },
        mistral = { chat_agent = "Open-Mixtral-8x7B", command_agent = "Mistral-Medium" },
        pplx = { chat_agent = "Llama3-Sonar-Large-32k-Chat", command_agent = "Llama3-70B-Instruct" },
        anthropic = { chat_agent = "Claude-3-Haiku-Chat", command_agent = "Claude-3.5-Sonnet" },
        openai = { chat_agent = "ChatGPT4", command_agent = "CodeGPT4o" },
        provider = "ollama",
      }, state._state)
    end)

    it("should switch to default provider, if previous state provider gets unavailable", function()
      local state = State:new("/tmp")
      state.file_state = {
        provider = "anthropic",
        anthropic = { command_agent = "Claude-3-Haiku", chat_agent = "Claude-3-Haiku-Chat" },
        openai = { command_agent = "CodeGPT3.5", chat_agent = "ChatGPT3.5" },
        ollama = { command_agent = "Llama2-13B", chat_agent = "Llama2-13B" },
      }

      local available_providers = { "ollama", "openai" }
      local available_agents = {
        ollama = { chat = { "Gemma-7B" }, command = { "Gemma-7B" } },
        openai = { chat = { "ChatGPT4" }, command = { "CodeGPT4o" } },
        provider = "anthropic",
      }

      state:refresh(available_providers, available_agents)

      assert.are.same({
        ollama = { chat_agent = "Gemma-7B", command_agent = "Gemma-7B" },
        openai = { chat_agent = "ChatGPT4", command_agent = "CodeGPT4o" },
        provider = "ollama",
      }, state._state)
    end)
  end)

  describe("save", function()
    before_each(setup_mocks)
    after_each(teardown_mocks)

    it("should save state to file", function()
      local state = State:new("/tmp")
      state._state = {
        ollama = {
          command_agent = "Gemma-7B",
          chat_agent = "Gemma-7B",
        },
        mistral = {
          command_agent = "Mistral-Medium",
          chat_agent = "Open-Mixtral-8x7B",
        },
        pplx = {
          command_agent = "Llama3-70B-Instruct",
          chat_agent = "Llama3-Sonar-Large-32k-Chat",
        },
        anthropic = {
          command_agent = "Claude-3.5-Sonnet",
          chat_agent = "Claude-3-Haiku-Chat",
        },
        openai = {
          command_agent = "CodeGPT4o",
          chat_agent = "ChatGPT4",
        },
        provider = "anthropic",
      }

      state:save()

      assert
        .stub(require("parrot.file_utils").table_to_file)
        .was_called_with(state._state, "/tmp/state.json")
    end)
  end)

  describe("set_provider", function()
    it("should set the current provider", function()
      local state = State:new("/tmp")

      state:set_provider("anthropic")

      assert.are.same("anthropic", state._state.provider)
    end)
  end)

  describe("set_agent", function()
    it("should set the chat agent for a provider", function()
      local state = State:new("/tmp")
      state._state = { anthropic = {} }

      state:set_agent("anthropic", "Claude-3-Haiku-Chat", "chat")

      assert.are.same("Claude-3-Haiku-Chat", state._state.anthropic.chat_agent)
    end)

    it("should set the command agent for a provider", function()
      local state = State:new("/tmp")
      state._state = { anthropic = {} }

      state:set_agent("anthropic", "Claude-3.5-Sonnet", "command")

      assert.are.same("Claude-3.5-Sonnet", state._state.anthropic.command_agent)
    end)
  end)

  describe("get_provider", function()
    it("should return the current provider", function()
      local state = State:new("/tmp")
      state._state = { provider = "anthropic" }

      local result = state:get_provider()

      assert.are.same("anthropic", result)
    end)
  end)

  describe("get_agent", function()
    it("should return the chat agent for a provider", function()
      local state = State:new("/tmp")
      state._state = { anthropic = { chat_agent = "Claude-3-Haiku-Chat" } }

      local result = state:get_agent("anthropic", "chat")

      assert.are.same("Claude-3-Haiku-Chat", result)
    end)

    it("should return the command agent for a provider", function()
      local state = State:new("/tmp")
      state._state = { anthropic = { command_agent = "Claude-3.5-Sonnet" } }

      local result = state:get_agent("anthropic", "command")

      assert.are.same("Claude-3.5-Sonnet", result)
    end)
  end)
end)
