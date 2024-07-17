# hunt_handbook

The intent of the hunt handbook is to define tasks ahead of mission time so that they are clearly thought out, tested, and vetted within the team.  These tasks can then be used by an analyst when they are looking for prompts to refine and continue their hunt.  Also leadership can assign tasks to analyst and the outcomes should help to feed the mission and reporting requirements.

The documentation is using squidfunk/mkdocs-material formatted MD notes.

## Run a local copy of the documentation

Run this documentation on a **Microsoft Windows** laptop to assist with kit installation and configuration.

- Download and install [docker desktop](https://www.docker.com/products/docker-desktop) - Windows version
- Clone this repo
- With **Docker Desktop** installed the docker commands should be available in a terminal (Windows Subsystem for Linux)
- Change directory to the root of the repo
- Run the following commands

  ```shell
  docker compose pull
  docker compose up -d
  ```

- Navigate to `http://localhost:8000`
