<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 Thomas Miceli
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Label Studio

This is an [Ansible](https://www.ansible.com/) role which installs [Label Studio](https://labelstud.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Label Studio is an open-source data labeling tool that supports multiple projects.

See the project's [documentation](https://labelstud.io/quick-start/) to learn what Label Studio does and why it might be useful to you.

## Prerequisites

To run an Label Studio it is necessary to prepare a database. You can use [Postgres](https://www.postgresql.org/) or [SQLite](https://www.sqlite.org/). The SQLite database file will be automatically created by the service if it is enabled.

If you are looking for an Ansible role for Postgres, you can check out [this role (ansible-role-postgres)](https://github.com/mother-of-all-self-hosting/ansible-role-postgres) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

## Adjusting the playbook configuration

To enable Label Studio with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# labelstudio                                                          #
#                                                                      #
########################################################################

labelstudio_enabled: true

########################################################################
#                                                                      #
# /labelstudio                                                         #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Label Studio you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
labelstudio_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Specify database

It is necessary to select database used by Label Studio from Postgres and SQLite.

To use Postgres, add the following configuration to your `vars.yml` file:

```yaml
labelstudio_database_type: postgres
```

Set `sqlite` to use SQLite. The SQLite database is stored in the directory specified with `labelstudio_data_path`.

For other settings, check variables such as `labelstudio_database_*` on [`defaults/main.yml`](../defaults/main.yml).

### Creating the administrator account

Who ends up owning your instance is decided on its first start, so it is worth deciding it yourself.

If you tell Label Studio about an administrator, it creates that account while setting its database up, and refuses every sign-up that does not come through an invitation link:

```yml
labelstudio_environment_variables_disable_signup_without_link: true
labelstudio_environment_variables_username: "admin-username"
labelstudio_environment_variables_password: "admin-user-password"
```

If you do not, Label Studio serves an open registration form at `/user/signup/`, and whoever submits it first becomes the first user of the instance and the owner of its organization. Since this role publishes Label Studio on a public hostname, that is a race with the internet — so setting the three variables above before the first installation is strongly recommended.

An invitation link for further accounts is available in the web interface under *Organization* → *Members*.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `labelstudio_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Label Studio becomes available at the specified hostname like `https://example.com`.

To get started, open the URL with a web browser and log in as the administrator you configured above. If you did not configure one, the page invites you to register an account — do so immediately, because until somebody does, the invitation is open to everyone who finds the hostname.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu labelstudio` (or how you/your playbook named the service, e.g. `mash-labelstudio`).
