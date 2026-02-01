{
  description = "Project environment powered by agentboxes";

  inputs = {
    agentboxes.url = "github:farra/agentboxes";
  };

  outputs = { self, agentboxes }:
    agentboxes.lib.mkProjectOutputs ./deps.toml;
}
