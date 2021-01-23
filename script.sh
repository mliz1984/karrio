#!/usr/bin/env bash

# Python virtual environment helpers
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BASE_DIR="${PWD##*/}"
ENV_DIR=".venv"
export wheels=~/Wheels
export PIP_FIND_LINKS="https://git.io/purplship"
[[ -d "$wheels" ]] && export PIP_FIND_LINKS=file://${wheels}

## icon vars
cross="\xE2\x9D\x8C"
check="\xE2\x9C\x94"

## color vars
default="$(tput sgr0)"
green="$(tput setaf 2)"
red="$(tput setaf 1)"


activate_env() {
  	echo "Activate $BASE_DIR env"
	deactivate >/dev/null 2>&1
	# shellcheck source=src/script.sh
	source "${ROOT:?}/$ENV_DIR/$BASE_DIR/bin/activate"
}

create_env() {
    echo "create $BASE_DIR env"
    deactivate >/dev/null 2>&1
    rm -rf "${ROOT:?}/$ENV_DIR"
    mkdir -p "${ROOT:?}/$ENV_DIR"
    python3 -m venv "${ROOT:?}/$ENV_DIR/$BASE_DIR" &&
    activate_env &&
    pip install --upgrade pip wheel > /dev/null
}

submodules() {
    find "${ROOT:?}/extensions" -type f -name "setup.py" ! -path "*$ENV_DIR/*" -exec dirname '{}' \;
}

init() {
	echo "Dev setup..."
    create_env &&
    pip install -r "${ROOT:?}/requirements.dev.txt" > /dev/null
}

# Project helpers

# shellcheck disable=SC2120
test() {
	echo "Running tests..."
    cd "${ROOT:?}"
    r=$(coverage run -m unittest discover -f -v "${ROOT:?}/tests"; echo $?)
    cd - >/dev/null 2>&1
    return ${r}
}

typecheck() {
	echo "Checking typing..."
    packages=(${ROOT}"/purplship")
    packages+=($(submodules))
	for module in ${packages}; do
		for submodule in $(find ${module} -type f -name "__init__.py" -exec dirname '{}' \;); do
			mypy ${submodule} || return $?;
		done;
    done
}

check() {
    typecheck && test
}

backup() {
    echo "Listing submodules..."
    [[ -d "$wheels" ]] &&
    find . -not -path "*$ENV_DIR/*" -name \*.whl -prune -exec mv '{}' "$wheels" \; &&
    clean
}

build() {
    clean
    echo "building wheels..."
    packages=(${ROOT})
    packages+=($(submodules))
	for pkg in ${packages}; do
		cd ${pkg};
		output=$(python setup.py -q bdist_wheel 2>&1);
		r=$?;
		cd - > /dev/null;
		if [[ ${r} -eq 1 ]]; then
			echo "${red}> building "$(basename ${pkg})" ${cross} ${default} \n $output"; return ${r};
		else
			echo "${green}> building "$(basename ${pkg})" ${check} ${default}";
		fi;
    done
    backup
}

updaterelease() {
    git tag -f -a "$1"
    git push -f --tags
}

clean() {
    echo "cleaning build files..."
    find . -type d -not -path "*$ENV_DIR/*" -name dist -prune -exec rm -r '{}' \; || true
    find . -type d -not -path "*$ENV_DIR/*" -name build -prune -exec rm -r '{}' \; || true
    find . -type d -not -path "*$ENV_DIR/*" -name "*.egg-info" -prune -exec rm -r '{}' \; || true
}

cli() {
	echo "running Python cli..."
	python "${ROOT:?}/cli.py" "$@"
}

docs() {
	cd "${ROOT:?}" && mkdocs serve -a localhost:4000; cd -
}


alias env:new=create_env
alias env:on=activate_env
alias env:reset=init

activate_env || true
