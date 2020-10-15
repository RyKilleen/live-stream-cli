# Live Stream CLI

## What is it?
Generate, start, and display a live stream in minutes!

This CLI tool leverage's Azure CLI to:

1. Create a live-stream endpoint
2. Start that end point, and provide you the URL you need to stream to
3. Generate a static site that displays the output from that live stream
4. Delete it all ($$$)

## Dependencies

1. [Azure CLI is installed](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. You have an Azure account, and have logged in via the CLI (`az login`)

## Getting Started
1. Clone this repo and run `npm install`
2. In your terminal, run  `.\videoStartup.ps1`
3. Run `New-Live-Stream some-name-here`
   - A caveat: naming across the different types of Azure resources is... intricate. Try and keep a short name, all lowercase.


## Roadmap
    - [ ] Find a way to generate static site without having to start the stream first
    - [ ] Better OS Support
    - [ ] Useful error handling (naming convention issues / regex, etc)
    - [ ] Script to pause livestream, not just delete it

