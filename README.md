# Markdown Converter

Markdown Converter is a tool that converts Markdown files into various formats such as PDF, HTML, and DOCX using Pandoc and LaTeX. It is designed to be flexible and customizable, supporting templates, filters, and additional features like hints and solutions for exercises.

## Features

- **Multi-format Conversion**: Convert Markdown files to PDF, HTML, or DOCX.
- **Custom Templates**: Use LaTeX and HTML templates for styling.
- **Hints and Solutions**: Dynamically include hints and solutions in exercises.
- **Dockerized Workflow**: Easily run the tool in a Docker container.
- **GitHub Actions Integration**: Automate the build and deployment process.

## Requirements

- [Docker](https://www.docker.com/)
- [Pandoc](https://pandoc.org/)
- [LaTeX](https://www.latex-project.org/)
- Additional dependencies: `jq`, `lua`, `luarocks`, `xelatex`, `nodejs`, `npm`

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/mdConverter.git
   cd mdConverter
   ```

2. Build the Docker image:
   ```bash
   docker build -t markdown-converter .
   ```

3. (Optional) Install dependencies locally if running without Docker:
   ```bash
   apk add --no-cache bash jq lua5.4 luarocks build-base unzip curl git nodejs npm tar ghc cabal
   cabal update && cabal install pandoc-sidenote
   ```

## Usage

### Using Docker

Run the converter with Docker:
```bash
docker run --rm -v $(pwd):/workspace markdown-converter ./convert_pdf.sh -c ./demo/config.json -t pdf -o ./output
```

### Without Docker

Run the script directly:
```bash
./convert_pdf.sh -c ./demo/config.json -t pdf -o ./output
```

### Options

- `-c, --config`: Path to the configuration JSON file (default: `./config.json`).
- `-t, --type`: Output format (`pdf`, `html`, `docx`, or `CC` for all formats).
- `-o, --outputDir`: Directory for the generated files (default: `./`).
- `-d, --debug`: Enable debug mode for detailed logs.

## Configuration

The `config.json` file specifies the structure of the document. It includes the following fields:

- `subjectName` (string): The name of the subject or project.
- `parts` (array): A list of parts in the document. Each part can have:
  - `subparts` (array): A list of subparts within the part. Each subpart includes:
    - `path` (string): The relative path to the Markdown file for the subpart.
    - `showHint` (boolean): Whether to include hints in the output (default: `false`).
    - `showSolution` (boolean): Whether to include solutions in the output (default: `false`).

### Example Configuration

```json
{
    "subjectName": "Demo Project",
    "parts": [
        {
            "title": "Part 1: Introduction",
            "subparts": [
                {
                    "title": "Getting Started",
                    "path": "Part01-Introduction/prise_en_main_editeur-exercice.md",
                    "showHint": true,
                    "showSolution": false
                },
                {
                    "title": "Screen Functionality",
                    "path": "Part01-Introduction/fonctionnement_ecran-exercice.md",
                    "showHint": false,
                    "showSolution": true
                }
            ]
        },
        {
            "title": "Part 2: Advanced Topics",
            "subparts": [
                {
                    "title": "Custom Filters",
                    "path": "Part02-Advanced/custom_filters.md",
                    "showHint": true,
                    "showSolution": true
                }
            ]
        }
    ]
}
```

### Notes

- The `title` field is optional but can be used to provide a descriptive name for parts and subparts.
- The `path` field must point to a valid Markdown file relative to the project root.
- The `showHint` and `showSolution` fields are optional and default to `false` if not specified.
- Additional metadata can be added to the configuration as needed for custom workflows.


## Hints and Solutions
Hints and solutions are included in the Markdown files using special syntax. For example:

```markdown
::: {.section-hintName01}
    your hint here
:::
```
```markdown
::: {.section-solutionName01}
    your solution here
:::
```
```markdown
::: {.solution path=./Part01-Introduction/prise_en_main_librairie-solution.md section=solutionName01}
:::
```
```markdown
::: {.hint path=./Part01-Introduction/prise_en_main_librairie-solution.md section=hintName01}
:::
```

These sections are dynamically included in the output based on the configuration file. The `path` attribute specifies the location of the hint or solution file, and the `section` attribute specifies which section to include.

## Templates

- **PDF Template**: Located at `template/pdf/template.tex`.
- **HTML Template**: Located at `template/html/standalone/template.html5`.

## Filters

Custom Lua filters are located in the `filter` directory. For example:
- `include_section.lua`: Dynamically includes sections like hints and solutions.

## GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/publish.yml`) to build and push the Docker image to GitHub Container Registry.

## Contributing

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Submit a pull request.


