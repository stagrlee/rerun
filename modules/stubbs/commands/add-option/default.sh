#!/usr/bin/env bash
#
# NAME
#
#   add-option
#
# DESCRIPTION
#
#   add a command option
#
#/ usage: stubbs:add-option [--arg <false>] --command|-c <> [--default|-d <>] --description <> [--export|-e <false>] [--long <>] --module|-m <> --option|-o <> [--required <false>] [--short <>]

# Source common function library
. $RERUN_MODULE_DIR/lib/functions.sh || { echo >&2 "failed laoding function library" ; exit 1 ; }


# Init the handler
rerun_init 

# Get the options
while [ "$#" -gt 0 ]; do
    OPT="$1"
    case "$OPT" in
        # options without arguments
	# options with arguments
	-o|--option)
	    rerun_option_check "$#" "$1"
	    OPTION="$2"
	    shift
	    ;;
	--desc*)
	    rerun_option_check "$#" "$1"
	    DESC="$2"
	    shift
	    ;;
	-c|--command)
	    rerun_option_check "$#" "$1"
		# Parse if command is named "module:command"
	 	regex='([^:]+)(:)([^:]+)'
		if [[ $2 =~ $regex ]]
		then
			MODULE=${BASH_REMATCH[1]}
			COMMAND=${BASH_REMATCH[3]}
		else
	    	COMMAND="$2"		
	    fi
	    shift
	    ;;
	-m|--module)
	    rerun_option_check "$#" "$1"
	    MODULE="$2"
	    shift
	    ;;
	--export|-e)
	    rerun_option_check "$#" "$1"
	    EXPORT="$2"
	    shift
	    ;;
	--req*)
	    rerun_option_check "$#" "$1"
	    REQ="$2"
	    shift
	    ;;
	--arg*)
	    rerun_option_check "$#" "$1"
	    ARGS="$2"
	    shift
	    ;;
	--long)
	    rerun_option_check "$#" "$1"
	    LONG="$2"
	    shift
	    ;;	
	-d|--default)
	    rerun_option_check "$#" "$1"
	    DEFAULT="$2"
	    shift
	    ;;
        # unknown option
	-?)
	    rerun_option_usage
        exit 2
	    ;;
	  # end of options, just arguments left
	*)
	    break
    esac
    shift
done


[ -z "$MODULE" ] && {
    echo "Module: "
    select MODULE in $(rerun_modules $RERUN_MODULES);
    do
	echo "You picked module $MODULE ($REPLY)"
	break
    done
}
# check the chosen module exists
[ ! -f $RERUN_MODULES/$MODULE/metadata ] && rerun_die "module not found: $MODULE"

[ -z "$COMMAND" ] && {
    echo "Command: "
    select COMMAND in $(rerun_commands $RERUN_MODULES $MODULE);
    do
	echo "You picked command $COMMAND ($REPLY)"
	break
    done
}

# Verify this command exists
#
[ -d $RERUN_MODULES/$MODULE/commands/$COMMAND ] || {
    rerun_option_error "command not found: \""$MODULE:$COMMAND\"""
}

# Post process the options
[ -z "$OPTION" ] && {
    echo "Option: "
    read OPTION
}

[ -z "$DESC" ] && {
    echo "Description: "
    read DESC
}

[ -z "$REQ" ] && {
    echo "Required (true/false): "
    select REQ in true false;
    do
	break
    done
}

[ -z "$DEFAULT" ] && {
    echo "Default: "
    read DEFAULT
}

[ -z "$EXPORT" ] && EXPORT=false

# Generate metadata for new option

(
    cat <<EOF
# generated by stubbs:add-option
# $(date)
NAME=$OPTION
DESCRIPTION="$DESC"
ARGUMENTS=${ARGS:-true}
REQUIRED=${REQ:-true}
SHORT=${OPTION:0:1}
LONG=${LONG:-$OPTION}
DEFAULT=$DEFAULT
EXPORT=$EXPORT

EOF
) > $RERUN_MODULES/$MODULE/commands/$COMMAND/$OPTION.option || rerun_die
echo "Wrote option metadata: $RERUN_MODULES/$MODULE/commands/$COMMAND/$OPTION.option"


# Read language setting for module. Set it to 'bash' as a default.
LANGUAGE=$(. $RERUN_MODULES/$MODULE/metadata; echo ${LANGUAGE:-bash});

# Generate option parser script.

[ ! -f $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata ] && rerun_die "language unsupported: $LANGUAGE"

.  $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata || rerun_die "error reading  $RERUN_MODULE_DIR/lib/$LANGUAGE/metadata "

[ -z "$RERUN_OPTIONS_GENERATOR" ] && rerun_die "required metadata not found: RERUN_OPTIONS_GENERATOR"
[ -z "$RERUN_OPTIONS_SCRIPT" ] && rerun_die "required metadata not found: RERUN_OPTIONS_SCRIPT"

optionsParserScript=$RERUN_MODULES/$MODULE/commands/$COMMAND/$RERUN_OPTIONS_SCRIPT

$RERUN_MODULE_DIR/lib/$LANGUAGE/$RERUN_OPTIONS_GENERATOR \
    $RERUN_MODULES $MODULE $COMMAND > $optionsParserScript || rerun_die

[ -z "$RERUN_COMMAND_SCRIPT" ] && rerun_die "required metadata not found: RERUN_COMMAND_SCRIPT"


# Update the command script header to give it the updated
# variable summary and usage info.
commandScript=$RERUN_MODULES/$MODULE/commands/$COMMAND/$RERUN_COMMAND_SCRIPT
if [ -f "$commandScript" ]
then
    rerun_rewriteCommandScriptHeader \
        $RERUN_MODULES $MODULE $COMMAND > ${commandScript}.$$ || {
        rerun_die "Error updating command script header"
    }
    mv $commandScript.$$ $commandScript || {
        rerun_die "Error updating command script header"
    }
    echo "Updated command script header: $commandScript"
fi

# Done
exit $?

