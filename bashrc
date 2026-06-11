#! /bin/bash

# ~/.bashrc: executed by bash for interactive non-login shells.

if [ -r /etc/skel/.bashrc ]; then
  source /etc/skel/.bashrc
fi

assume_role() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <aws-role-arn-to-assume>. Make sure the current user/profile has permissions to assume role" >&2
    return 1
  fi

  # shellcheck disable=SC2046
  # shellcheck disable=SC2183
  export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
    $(aws sts assume-role \
      --role-arn "$1" \
      --role-session-name moulick-local-test \
      --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
      --output text \
    )
  )
}
