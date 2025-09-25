self: super: {
libconfig = super.libconfig.overrideAttrs (oldAttrs: {
doCheck = false;
});
}