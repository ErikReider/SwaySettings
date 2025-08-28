#include <glib.h>
#include <pwd.h>
#include <security/_pam_types.h>
#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/cdefs.h>
#include <unistd.h>

enum pam_status {
	PAM_STATUS_ERROR,
	PAM_STATUS_AUTH_FAILED,
	PAM_STATUS_AUTH_SUCESS,
};

struct data {
	const char *password;
};

static int conv_function(int num_msg, const struct pam_message **msg,
						 struct pam_response **resp, void *appdata_ptr) {
	*resp = calloc(num_msg, sizeof(struct pam_response));
	if (*resp == NULL) {
		g_critical("Could not allocate pam_response");
		return PAM_ABORT;
	}

	struct data *data = appdata_ptr;
	for (int i = 0; i < num_msg; ++i) {
		resp[i]->resp_retcode = 0;

		switch (msg[i]->msg_style) {
		case PAM_PROMPT_ECHO_OFF:
		case PAM_PROMPT_ECHO_ON:
			resp[i]->resp = strdup(data->password);
			if (resp[i]->resp == NULL) {
				g_critical("Could not duplicate string");
				return PAM_ABORT;
			}
			break;
		case PAM_ERROR_MSG:
			// TODO: Display this
			g_critical("PAM error message: %s", msg[i]->msg);
			break;
		case PAM_TEXT_INFO:
			g_info("PAM info message: %s", msg[i]->msg);
			break;
		default:
			g_critical("PAM conv: unhandled message style: %i",
					   msg[i]->msg_style);
		}
	}

	return PAM_SUCCESS;
}

enum pam_status _check_password(const char *password) {
	pam_handle_t *pam_handle = NULL;
	struct passwd *pwd = getpwuid(getuid());
	if (!pwd) {
		perror("getpwuid error");
		return PAM_STATUS_ERROR;
	}

	struct data data = {
		.password = password,
	};
	struct pam_conv conv = {
		.conv = conv_function,
		.appdata_ptr = &data,
	};

	int pam_status =
		pam_start("swaysettings-locker", pwd->pw_name, &conv, &pam_handle);
	if (pam_status != PAM_SUCCESS) {
		g_critical("pam_start failed");
		return PAM_STATUS_ERROR;
	}

	int auth_status = pam_authenticate(pam_handle, 0);

	pam_status = pam_setcred(pam_handle, PAM_REFRESH_CRED);
	if (pam_end(pam_handle, pam_status) != PAM_SUCCESS) {
		g_critical("pam_end failed");
	}
	return auth_status == PAM_SUCCESS ? PAM_STATUS_AUTH_SUCESS
									  : PAM_STATUS_AUTH_FAILED;
}
