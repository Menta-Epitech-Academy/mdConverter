#!/bin/bash

#----------------------------
#GLOBAL VARIABLES
#----------------------------

SCRIPT_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$SCRIPT_DIR" ]]; then SCRIPT_DIR="$PWD"; fi

ERROR_CODE=1

CONFIG_FILE="./config.json"
OUTPUT_TYPE="pdf"
OUTPUT_DIR="."

FILTER_DIR="${SCRIPT_DIR}/filter"
FILTER_FILE="${FILTER_DIR}/init.lua"

TEMPLATE_DIR="${SCRIPT_DIR}/template/"
TEMPLATE_FILE="${TEMPLATE_DIR}/pdf/template.tex"
DEBUG=0

#----------------------------
# DEPENDENCIES
#----------------------------

DEPENDENCIES=(jq pandoc xelatex)

for dependency in "${DEPENDENCIES[@]}"; do
    if ! command -v $dependency &> /dev/null; then
        echo -e "$dependency not found !"
        exit $ERROR_CODE
    fi
done

#----------------------------
# SUPPORTED FORMATS AND THEIR OPTIONS
#----------------------------

declare -A FORMAT_OPTIONS=(
    [pdf]="--pdf-engine=xelatex --lua-filter=${FILTER_FILE} --metadata title=$subject_name --toc --number-sections --standalone"
    [docx]="--lua-filter=${FILTER_FILE}"
    [html-stdl]="--lua-filter=${FILTER_FILE} --embed-resources --katex --from markdown+tex_math_single_backslash --filter pandoc-sidenote --to html5+smart --template=${TEMPLATE_DIR}/html/standalone/template.html5 --css=${TEMPLATE_DIR}/html/standalone/css/theme.css --css=${TEMPLATE_DIR}/html/standalone/css/skylighting-paper-theme.css --toc --wrap=none --metadata title=$subject_name"
    [html]="--lua-filter=${FILTER_FILE} --embed-resources --katex --from markdown+tex_math_single_backslash --filter pandoc-sidenote --to html5+smart --template=${TEMPLATE_DIR}/html/standalone/template.html5 --toc --wrap=none --metadata title=$subject_name"

)

#----------------------------
# FUNCTION
#----------------------------

#----------------------------
# extract_name
# @param config_content the content of the config.json file
# @return the subject name
#----------------------------
function extract_name
{
    local config_content="$1"
    if [ -z "$config_content" ]; then
        echo "Erreur : Aucun nom de sujet fourni."
        exit 1
    fi

    local config_subjectname=$(jq -r '.subjectName' <<< "$config_content" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$config_subjectname" ]; then
        echo "Erreur : Le nom de sujet est vide ou absent dans config.json."
        exit $ERROR_CODE
    fi

    echo "$config_subjectname"
}

#----------------------------
# extract_file
# @param config_content the content of the config.json file
# @return the list of files to convert
#----------------------------
function extract_file {
    local config_content="$1"

    local config_parts=$(jq -c '.parts[]' <<< "$config_content" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$config_parts" ]; then
        echo "Erreur : Impossible de lire les parties depuis config.json. Vérifiez que le fichier est valide."
        exit $ERROR_CODE
    fi

    local files_list=()
    for part in $config_parts; do
        subparts=$(jq -c '.subparts[]' <<< "$part" 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$subparts" ]; then
            echo "Erreur : Impossible de lire les sous-parties pour la partie suivante : $part. Vérifiez que le fichier est valide."
            continue
        fi

        for subpart in $subparts; do
            subpart_file=$(jq -r '.path' <<< "$subpart" 2>/dev/null)

            if [ -f "$subpart_file" ]; then
                files_list+=("$subpart_file")
            else
                echo "Fichier $subpart_file introuvable."
            fi
        done
    done

    echo "${files_list[@]}" | tr ' ' '\n'
}

#----------------------------
# convert
# @param output_name the name of the output file
# @param flag the pandoc flag
# @param extension the file extension
# @param files_list the list of files to convert
#----------------------------
function convert {
    local output_name="$1"
    local flag="$2"
    local extension="$3"
    local files_list=("${@:4}")
    local verbose_flag=""

    if [ -z "$output_name" ]; then
        echo "Erreur : Aucun nom de fichier de sortie fourni."
        exit $ERROR_CODE
    fi
    if [ -z "$extension" ]; then
        echo "Erreur : Aucun type de fichier fourni."
        exit $ERROR_CODE
    fi
    if [ ${#files_list[@]} -eq 0 ]; then
        echo "Erreur : Aucun fichier à convertir trouvé."
        exit $ERROR_CODE
    fi
    
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        if [ $? -ne 0 ]; then
            echo "Erreur : Impossible de créer le répertoire de sortie $OUTPUT_DIR."
            exit $ERROR_CODE
        fi
    fi
    [ "$DEBUG" -eq 1 ] && verbose_flag="--verbose"

    pandoc "${files_list[@]}" $flag -o "$OUTPUT_DIR/$output_name.$extension"  $verbose_flag
    if [ $? -eq 0 ]; then
        echo "${extension} généré avec succès : $output_name.$extension"
    else
        echo "Erreur lors de la génération du $extension."
        exit $ERROR_CODE
    fi
}

convert_format() {
    local format="$1"
    local options="${FORMAT_OPTIONS[$format]}"
    
    if [[ -z "$options" ]]; then
        echo "Erreur : format non supporté : $format" >&2
        exit $ERROR_CODE
    fi

    [[ "$format" == "html" || "$format" == "html-stdl" ]] && cp -r "./static" "$OUTPUT_DIR"
    [[ "$format" == "html-stdl" ]] && cp -r "${TEMPLATE_DIR}/html/standalone/js" "$OUTPUT_DIR"

    echo "Conversion en ${format^^}..."
    [[ "$format" == "html-stdl" ]] && format="html" || format="$format"
    convert "$subject_name" "$options" "$format" "${files_list[@]}"
}


#----------------------------
# PARSING ARGUMENTS
#----------------------------

USAGE="Usage: $0 [options]
Options:
  -h, --help        Affiche ce message d'aide et quitte.
  -c, --config      Chemin vers le fichier de configuration JSON. Par défaut : './config.json'.
  -t, --type        Type de document à générer. Par défaut : 'pdf'.
  -o, --outputDir   Répertoire de sortie pour les fichiers générés. Par défaut : './'.
  -d, --debug       Active le mode débogage pour afficher les informations détaillées sur le processus.
  "

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "$USAGE"
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -t|--type)
            OUTPUT_TYPE="$2"
            shift 2
            ;;
        -o|--outputDir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=1
            shift
            ;;
        *)
            echo "Option inconnue : $1"
            echo "$USAGE"
            exit $ERROR_CODE
            ;;
    esac
done


#----------------------------
# MAIN SCRIPT
#----------------------------

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur : Le fichier config.json est introuvable."
    exit $ERROR_CODE
fi

config_content=$(jq '.' "$CONFIG_FILE" 2>/dev/null)

subject_name=$(extract_name "$config_content")
if [ $? -ne 0 ]; then
    echo "Erreur : Impossible d'extraire le nom du sujet."
    exit $ERROR_CODE
fi
echo "Nom du sujet : $subject_name"

mapfile -t files_list < <(extract_file "$config_content")

if [ ${#files_list[@]} -eq 0 ]; then
    echo "Erreur : Aucun fichier à convertir trouvé dans config.json."
    exit $ERROR_CODE
fi

echo "Fichiers à convertir :"
for file in "${files_list[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Erreur : Le fichier $file n'existe pas."
        exit $ERROR_CODE
    fi
    echo " - $file"
done

if [ -z "$OUTPUT_TYPE" ]; then
    OUTPUT_TYPE="pdf"
fi

if [[ "$OUTPUT_TYPE" == "CC" ]]; then
    for format in pdf docx html-stdl; do
        convert_format "$format"
    done
else
    convert_format "$OUTPUT_TYPE"
fi