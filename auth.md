# Authentication

## Generating Oauth Credentials

- Follow [Enable Drive API](#enable-drive-api) section.
- Open [google console](https://console.developers.google.com/).
- Click on "Credentials".
- Click "Create credentials" and select oauth client id.
- Select Application type "Desktop app" or "other".
- Provide name for the new credentials. ( anything; this Google Console label is unrelated to gdl account names )
- This would provide a new Client ID and Client Secret.
- Download your credentials.json by clicking on the download button.

Now, we have obtained our credentials, move to the [First run](#first-run) section to use those credentials.

## First run

Run:

```shell
gdl gdrive_url/gdrive_id -o
```

Important:

- `-o/--oauth` takes no Client ID or Client Secret arguments.
- Do not pass credentials on the command line.
- The first prompt asks for a **local account name** (alias), for example `default`.
- That account name is only used inside `${HOME}/.gdl.conf` (`ACCOUNT_<name>_CLIENT_ID`, etc). It is not your Google account and not the Client ID.
- Allowed characters: alphabets, numbers, underscores.

After the account name, paste Client ID and Client Secret from `credentials.json`, then either paste an existing Refresh Token or leave it blank and complete the browser authorization flow.

For the full authentication and config reference, see the Authentication section in [README.md](README.md#authentication).

## Enable Drive API

- Log into google developer console at [google console](https://console.developers.google.com/).
- Click select project at the right side of "Google Cloud Platform" of upper left of window.

If you cannot see the project, please try to access to [https://console.cloud.google.com/cloud-resource-manager](https://console.cloud.google.com/cloud-resource-manager).

You can also create new project at there. When you create a new project there, please click the left of "Google Cloud Platform". You can see it like 3 horizontal lines.

By this, a side bar is opened. At there, select "API & Services" -> "Library". After this, follow the below steps:

- Click "NEW PROJECT" and input the "Project Name".
- Click "CREATE" and open the created project.
- Click "Enable APIs and get credentials like keys".
- Go to "Library"
- Input "Drive API" in "Search for APIs & Services".
- Click "Google Drive API" and click "ENABLE".

[Go back to oauth credentials setup](#generating-oauth-credentials)

### Retrieve API key

In order to use a custom api key, follow the below steps:

- Follow [Enable Drive API](#enable-drive-api) section.
- Open [google console](https://console.developers.google.com/).
- Click on "Credentials".
- Click "Create credentials" and select API key.
- Copy the API key. You can use this API key.
