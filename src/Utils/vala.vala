namespace Utils.Vala {
    public static inline EnumClass get_enum_class<T> () {
        return (EnumClass) typeof (T).class_ref ();
    }
}
