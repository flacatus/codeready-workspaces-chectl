#!/bin/bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# convert chectl upstream to downstream using sed & perl transforms, and deleting files

set -e

MIDSTM_BRANCH="crw-2.5-rhel-8"
DEFAULT_TAG=${MIDSTM_BRANCH#*-}; DEFAULT_TAG=${DEFAULT_TAG%%-*};

usage () {
	echo "Usage:   $0 -b MIDSTM_BRANCH -s SOURCEDIR -t TARGETDIR"
	echo "Example: $0 -b crw-2.5-rhel-8 -s /path/to/chectl -t /path/to/crwctl"
	echo ""
	echo "Options:
	--server-tag ${DEFAULT_TAG}-xx   (instead of default ${DEFAULT_TAG})
	--operator-tag ${DEFAULT_TAG}-yy (instead of default ${DEFAULT_TAG})
	"
	exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b'|'--crw-branch') MIDSTM_BRANCH="$2"; shift 1;; # branch of redhat-developer/codeready-workspaces/pom.xml to check as default CHE_VERSION
	# paths to use for input and ouput
	'-s') SOURCEDIR="$2"; SOURCEDIR="${SOURCEDIR%/}"; shift 1;;
	'-t') TARGETDIR="$2"; TARGETDIR="${TARGETDIR%/}"; shift 1;;
	'--help'|'-h') usage;;
	# optional tag overrides
	'--server-tag') CRW_SERVER_TAG="$2"; shift 1;;
	'--operator-tag') CRW_OPERATOR_TAG="$2"; shift 1;;
  esac
  shift 1
done

if [[ ! -d "${SOURCEDIR}" ]]; then usage; fi
if [[ -z "${TARGETDIR}" ]]; then usage; else mkdir -p "${TARGETDIR}"; fi

# if not set use crw-2.5-rhel-8 ==> 2.5 as the default tag
if [[ -z "${CRW_SERVER_TAG}" ]];   then CRW_SERVER_TAG=${MIDSTM_BRANCH#*-};   CRW_SERVER_TAG=${CRW_SERVER_TAG%%-*};     fi
if [[ -z "${CRW_OPERATOR_TAG}" ]]; then CRW_OPERATOR_TAG=${MIDSTM_BRANCH#*-}; CRW_OPERATOR_TAG=${CRW_OPERATOR_TAG%%-*}; fi

# global / generic changes
pushd "${SOURCEDIR}" >/dev/null
	while IFS= read -r -d '' d; do
		echo "[INFO] Convert ${d}"
		if [[ -d "${SOURCEDIR}/${d%/*}" ]]; then mkdir -p "${TARGETDIR}"/"${d%/*}"; fi
		sed -r \
			-e "s|route_names = \['che'|route_names = \['codeready'|g" \
			-e "s|https://github.com/che-incubator/chectl|https://github.com/redhat-developer/codeready-workspaces-chectl|g" \
			-e "s|chectl|crwctl|g" \
			-e "s|crwctl-generated|chectl-generated|g" \
			-e "s|labelSelector=app%3Dche|labelSelector=app%3Dcodeready|g" \
			\
			-e "s|/codeready-workspaces-crwctl|/codeready-workspaces-chectl|g" \
			-e "s|app=che|app=codeready|g" \
			-e "s|app=codeready,component=che|app=codeready,component=codeready|" \
			-e "s|che-operator|codeready-operator|g" \
			-e "s| && isStableVersion\(flags\)||g" \
			-e "s|, isStableVersion||g" \
			-e "s|/codeready-operator/|/codeready-workspaces-operator/|g" \
			\
			-e "s|codeready-operator-(cr.+yaml)|che-operator-\1|g" \
			-e "s|codeready-operator-(cr.+yaml)|che-operator-\1|g" \
			-e "s|codeready-operator-image|che-operator-image|g" \
			-e "s|CHE_CLUSTER_CR_NAME = 'eclipse-che'|CHE_CLUSTER_CR_NAME = 'codeready-workspaces'|g" \
			-e "s|Eclipse Che|CodeReady Workspaces|g" \
			\
			-e "s| when both minishift and OpenShift are stopped||" \
			-e "s|resource: Kubernetes/OpenShift/Helm|resource|g" \
			-e "/import \{ HelmTasks \} from '..\/..\/tasks\/installers\/helm'/d" \
			-e "/import \{ MinishiftAddonTasks \} from '..\/..\/tasks\/installers\/minishift-addon'/d" \
			-e "/    const helmTasks = new HelmTasks\(flags\)/d" \
			-e "/    const (minishiftAddonTasks|msAddonTasks) = new MinishiftAddonTasks\(\)/d" \
			-e '/.+tasks.add\(helmTasks.+/d' \
			-e '/.+tasks.add\((minishiftAddonTasks|msAddonTasks).+/d' \
			-e "s|(const DEFAULT_CHE_IMAGE =).+|\1 'registry.redhat.io/codeready-workspaces/server-rhel8:${CRW_SERVER_TAG}'|g" \
			-e "s|(const DEFAULT_CHE_OPERATOR_IMAGE =).+|\1 'registry.redhat.io/codeready-workspaces/crw-2-rhel8-operator:${CRW_OPERATOR_TAG}'|g" \
			\
			-e "s|(const CHE_CLUSTER_CR_NAME =).+|\1 'codeready-workspaces'|g" \
			\
			-e "s|(const DEFAULT_CHE_OLM_PACKAGE_NAME =).+|\1 'codeready-workspaces'|g" \
			-e "s|(const OLM_STABLE_CHANNEL_NAME =).+|\1 'latest'|g" \
			-e "s|(const CUSTOM_CATALOG_SOURCE_NAME =).+|\1 'codeready-custom-catalog-source'|g" \
			-e "s|(const SUBSCRIPTION_NAME =).+|\1 'codeready-subscription'|g" \
			-e "s|(const OPERATOR_GROUP_NAME =).+|\1 'codeready-operator-group'|g" \
			-e "s|(const OPENSHIFT_OLM_CATALOG =).+|\1 'redhat-operators'|g" \
			-e "s|(CVS_PREFIX =).+|\1 'crwoperator'|g" \
			\
			-e "s|\"CodeReady Workspaces will be deployed in Multi-User mode.+mode.\"|'CodeReady Workspaces can only be deployed in Multi-User mode.'|" \
			-e "s|che-incubator/crwctl|redhat-developer/codeready-workspaces-chectl|g" \
		"$d" > "${TARGETDIR}/${d}"
	done <   <(find src test -type f -name "*" -print0)
popd >/dev/null

# Remove files
pushd "${TARGETDIR}" >/dev/null
	while IFS= read -r -d '' d; do
		echo "[INFO] Delete ${d#./}"
		rm -f "$d"
		#
	done <   <(find . -regextype posix-extended -iregex '.+/(helm|minishift|minishift-addon|minikube|microk8s|k8s|docker-desktop)(.test|).ts' -print0)
popd >/dev/null

# per-file changes:
platformString="    platform: string({\n\
      char: 'p',\n\
      description: 'Type of OpenShift platform. Valid values are \\\\\"openshift\\\\\", \\\\\"crc (for CodeReady Containers)\\\\\".',\n\
      options: ['openshift', 'crc'],\n\
      default: 'openshift'\n\
    }),"; # echo -e "$platformString"
installerString="    installer: string({\n\
      char: 'a',\n\
      description: 'Installer type. If not set, default is "olm" for OpenShift >= 4.2, and "operator" for earlier versions.',\n\
      options: ['olm', 'operator']\n\
    }),"; # echo -e "$installerString"
pushd "${TARGETDIR}" >/dev/null
	for d in src/commands/server/update.ts src/commands/server/start.ts; do
		echo "[INFO] Convert ${d}"
		mkdir -p "${TARGETDIR}/${d%/*}"
		perl -0777 -p -i -e 's|(\ +platform: string\({.*?}\),)| ${1} =~ /.+minishift.+/?"INSERT-CONTENT-HERE":${1}|gse' "${TARGETDIR}/${d}"
		sed -r -e "s#INSERT-CONTENT-HERE#${platformString}#" -i "${TARGETDIR}/${d}"

		perl -0777 -p -i -e 's|(\ +installer: string\({.*?}\),)| ${1} =~ /.+minishift.+/?"INSERT-CONTENT-HERE":${1}|gse' "${TARGETDIR}/${d}"
		sed -r -e "s#INSERT-CONTENT-HERE#${installerString}#" -i "${TARGETDIR}/${d}"
		# Remove --domain flag
		sed -i '/domain: string({/,/}),/d' "${TARGETDIR}/${d}"
		# Change multi-user flag description. Code Ready Workspaces support multi-user by default. https://issues.redhat.com/browse/CRW-1174
		sed -i "s|'Starts CodeReady Workspaces in multi-user mode'|\`Starts CodeReady Workspaces in multi-user mode.\n\ \
		                Note, this option is turned on by default.\`|g" "${TARGETDIR}/${d}"
	done
popd >/dev/null

pushd "${TARGETDIR}" >/dev/null
	d=src/common-flags.ts
	echo "[INFO] Convert ${d}"
	mkdir -p "${TARGETDIR}/${d%/*}"
	sed -r \
		`# replace line after specified one with new default` \
		-e "s|Kubernetes namespace|Openshift Project|g" \
		-e "/description: 'Openshift Project/{n;s/.+/  default: 'workspaces',/}" \
		-e "/description: .+ deployment name.+/{n;s/.+/  default: 'codeready',/}" \
		-i "${TARGETDIR}/${d}"
popd >/dev/null

operatorTasksString="export class OperatorTasks {\n\
  operatorServiceAccount = 'codeready-operator'\n\
  operatorRole = 'codeready-operator'\n\
  operatorClusterRole = 'codeready-operator'\n\
  operatorRoleBinding = 'codeready-operator'\n\
  operatorClusterRoleBinding = 'codeready-operator'\n\
  cheClusterCrd = 'checlusters.org.eclipse.che'\n\
  operatorName = 'codeready-operator'\n\
  operatorCheCluster = 'codeready-workspaces'\n\
  resourcesPath = ''"
pushd "${TARGETDIR}" >/dev/null
	d=src/tasks/installers/operator.ts
	echo "[INFO] Convert ${d}"
	mkdir -p "${TARGETDIR}/${d%/*}"
	perl -0777 -p -i -e 's|(export class OperatorTasks.*?  resourcesPath = )|  ${1} =~ /.+che-operator.+/?"INSERT-CONTENT-HERE":${1}|gse' "${TARGETDIR}/${d}"
	sed -r -e "s#INSERT-CONTENT-HERE.+#${operatorTasksString}#" -i "${TARGETDIR}/${d}"
popd >/dev/null

# remove if blocks
pushd "${TARGETDIR}" >/dev/null
	for d in src/tasks/installers/installer.ts src/tasks/platforms/platform.ts; do
		echo "[INFO] Convert ${d}"
		mkdir -p "${TARGETDIR}/${d%/*}"
		sed -i -r -e '/.+BEGIN CHE ONLY$/,/.+END CHE ONLY$/d' "${TARGETDIR}/${d}"
		sed -r -e "/.*(import|const).+(Helm|Minishift|DockerDesktop|K8s|MicroK8s|Minikube).*Tasks.*/d" -i "${TARGETDIR}/${d}"
	done
popd >/dev/null

replaceVar()
{
  replaceFile="$1"
  updateName="$2"
  updateVal="$3"
  cat ${replaceFile} | jq --arg updateName "${updateName}" --arg updateVal "${updateVal}" ''${updateName}'="'${updateVal}'"' > ${replaceFile}.2
  if [[ $(cat ${replaceFile}) != $(cat ${replaceFile}.2) ]]; then
    echo -n " * $updateName: "
    cat "${replaceFile}" | jq --arg updateName "${updateName}" ''${updateName}'' 2>/dev/null
  fi
  mv ${replaceFile}.2 ${replaceFile}
}

# update package.json to latest branch of crw-operator
replaceVar "${TARGETDIR}/package.json" '.dependencies["codeready-workspaces-operator"]' "git://github.com/redhat-developer/codeready-workspaces-operator#${MIDSTM_BRANCH}"