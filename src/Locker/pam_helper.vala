public enum PamStatus {
    PAM_STATUS_ERROR,
    PAM_STATUS_AUTH_FAILED,
    PAM_STATUS_AUTH_SUCESS,
}

private extern PamStatus _check_password (Gtk.PasswordEntryBuffer pwd_buffer,
                                          List<string> **messages,
                                          List<string> **errors);

public class PamThread {
    private unowned SourceFunc callback;
    private unowned LockData lock_data;

    public PamStatus status = PamStatus.PAM_STATUS_ERROR;

    public PamThread (LockData lock_data,
                      SourceFunc callback) {
        this.lock_data = lock_data;
        this.callback = callback;
    }

    public void begin () {
        status = _check_password (lock_data.pwd_buffer,
                                  &lock_data.messages,
                                  &lock_data.errors);
        callback ();
    }
}

public async PamStatus check_password (LockData lock_data) {
    var checker = new PamThread (lock_data, check_password.callback);

    new Thread<void> (null, checker.begin);
    yield;

    return checker.status;
}
