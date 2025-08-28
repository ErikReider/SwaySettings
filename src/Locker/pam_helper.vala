public enum pam_status {
	PAM_STATUS_ERROR,
	PAM_STATUS_AUTH_FAILED,
	PAM_STATUS_AUTH_SUCESS,
}

private extern pam_status _check_password (string password);

public class PamThread {
    private unowned SourceFunc callback;
    private unowned string password;

    public pam_status status = pam_status.PAM_STATUS_ERROR;

    public PamThread (string password, SourceFunc callback) {
        this.password = password;
        this.callback = callback;
    }

    public void begin () {
        status =_check_password (password);
        callback ();
    }
}

public async pam_status check_password (string password) {
    var checker = new PamThread (password, check_password.callback);

    new Thread<void> (null, checker.begin);
    yield;

    return checker.status;
}
