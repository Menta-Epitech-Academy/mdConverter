#!/bin/bash

SCRIPT_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$SCRIPT_DIR" ]]; then SCRIPT_DIR="$PWD"; fi

ERROR_CODE=1

CONFIG_FILE="./config.json"


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
# convert_to_pdf
# @param files_list the list of files to convert
# @param subject_name the name of the subject
#----------------------------
function convert_to_pdf {
    local files_list=("$@")
    if [ ${#files_list[@]} -eq 0 ]; then
        echo "Erreur : Aucun fichier à convertir trouvé."
        exit $ERROR_CODE
    fi

    local output_name="${files_list[0]##*/}"
    unset 'files_list[0]'

    echo "Fichiers à convertir :${files_list[@]}"

    pandoc "${files_list[@]}" --pdf-engine=xelatex --lua-filter=${SCRIPT_DIR}/filter/init.lua -o "$output_name.pdf"
    if [ $? -eq 0 ]; then
        echo "PDF généré avec succès : $output_name.pdf"
    else
        echo "Erreur lors de la génération du PDF."
        exit $ERROR_CODE
    fi
}

#----------------------------
# PARSING ARGUMENTS
#----------------------------

USAGE="Usage: $0 [options]
Options:
  -h, --help        Affiche ce message d'aide et quitte.
  -c, --config      Chemin vers le fichier de configuration JSON. Par défaut : './config.json'.
  -t, --type        Type de document à générer. Par défaut : 'pdf'.
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

case $OUTPUT_TYPE in
    pdf)
        echo "Conversion en PDF..."
        convert_to_pdf "$subject_name" "${files_list[@]}" 
        ;;
    *)
        echo "Erreur : Type de document non pris en charge : $OUTPUT_TYPE"
        exit $ERROR_CODE
        ;;
esac
