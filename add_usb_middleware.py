Import("env")
import os

packages_dir = env.subst("$PROJECT_PACKAGES_DIR")
middleware = os.path.join(packages_dir, "framework-stm32cubef4",
                          "Middlewares", "ST", "STM32_USB_Device_Library")

env.Append(CPPPATH=[
    os.path.join(middleware, "Core", "Inc"),
    os.path.join(middleware, "Class", "CDC", "Inc"),
])

env.BuildSources(
    "$BUILD_DIR/MiddlewareUSB_Core",
    os.path.join(middleware, "Core", "Src"),
    src_filter="-<*> +<usbd_core.c> +<usbd_ctlreq.c> +<usbd_ioreq.c>"
)

env.BuildSources(
    "$BUILD_DIR/MiddlewareUSB_CDC",
    os.path.join(middleware, "Class", "CDC", "Src"),
    src_filter="-<*> +<usbd_cdc.c>"
)
