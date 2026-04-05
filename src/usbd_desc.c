#include "usbd_core.h"
#include "usbd_desc.h"
#include "usbd_conf.h"

/* STMicroelectronics VID / Virtual COM Port PID */
#define USBD_VID                    0x0483
#define USBD_PID_FS                 0x5740
#define USBD_LANGID_STRING          0x0409
#define USBD_MANUFACTURER_STRING    "STMicroelectronics"
#define USBD_PRODUCT_STRING_FS      "STM32 Virtual ComPort"
#define USBD_CONFIGURATION_STRING   "CDC Config"
#define USBD_INTERFACE_STRING       "CDC Interface"

#define DEVICE_ID1   (UID_BASE)
#define DEVICE_ID2   (UID_BASE + 0x4U)
#define DEVICE_ID3   (UID_BASE + 0x8U)
#define USB_SIZ_STRING_SERIAL  0x1AU

static uint8_t *USBD_FS_DeviceDescriptor  (USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_LangIDStrDescriptor(USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_ManufacturerStr   (USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_ProductStr        (USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_SerialStr         (USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_ConfigStr         (USBD_SpeedTypeDef speed, uint16_t *length);
static uint8_t *USBD_FS_InterfaceStr      (USBD_SpeedTypeDef speed, uint16_t *length);

USBD_DescriptorsTypeDef CDC_Desc = {
    USBD_FS_DeviceDescriptor,
    USBD_FS_LangIDStrDescriptor,
    USBD_FS_ManufacturerStr,
    USBD_FS_ProductStr,
    USBD_FS_SerialStr,
    USBD_FS_ConfigStr,
    USBD_FS_InterfaceStr,
};

__ALIGN_BEGIN static uint8_t hDeviceDesc[USB_LEN_DEV_DESC] __ALIGN_END = {
    0x12,                       /* bLength */
    USB_DESC_TYPE_DEVICE,       /* bDescriptorType */
    0x00, 0x02,                 /* bcdUSB 2.0 */
    0x02,                       /* bDeviceClass: CDC */
    0x00,
    0x00,
    USB_MAX_EP0_SIZE,
    LOBYTE(USBD_VID), HIBYTE(USBD_VID),
    LOBYTE(USBD_PID_FS), HIBYTE(USBD_PID_FS),
    0x00, 0x02,                 /* bcdDevice */
    USBD_IDX_MFC_STR,
    USBD_IDX_PRODUCT_STR,
    USBD_IDX_SERIAL_STR,
    USBD_MAX_NUM_CONFIGURATION
};

__ALIGN_BEGIN static uint8_t hLangIDDesc[USB_LEN_LANGID_STR_DESC] __ALIGN_END = {
    USB_LEN_LANGID_STR_DESC,
    USB_DESC_TYPE_STRING,
    LOBYTE(USBD_LANGID_STRING),
    HIBYTE(USBD_LANGID_STRING)
};

__ALIGN_BEGIN static uint8_t hStrDesc[USBD_MAX_STR_DESC_SIZ] __ALIGN_END;
__ALIGN_BEGIN static uint8_t hSerialStr[USB_SIZ_STRING_SERIAL] __ALIGN_END = {
    USB_SIZ_STRING_SERIAL,
    USB_DESC_TYPE_STRING,
};

static void IntToUnicode(uint32_t value, uint8_t *pbuf, uint8_t len)
{
    for (uint8_t i = 0; i < len; i++) {
        uint8_t nibble = (value >> 28) & 0xF;
        pbuf[2 * i]     = (nibble < 10) ? (nibble + '0') : (nibble - 10 + 'A');
        pbuf[2 * i + 1] = 0;
        value <<= 4;
    }
}

static void GetSerialNum(void)
{
    uint32_t d0 = *(uint32_t *)DEVICE_ID1 + *(uint32_t *)DEVICE_ID3;
    uint32_t d1 = *(uint32_t *)DEVICE_ID2;
    IntToUnicode(d0, &hSerialStr[2],  8);
    IntToUnicode(d1, &hSerialStr[18], 4);
}

static uint8_t *USBD_FS_DeviceDescriptor(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    *length = sizeof(hDeviceDesc);
    return hDeviceDesc;
}
static uint8_t *USBD_FS_LangIDStrDescriptor(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    *length = sizeof(hLangIDDesc);
    return hLangIDDesc;
}
static uint8_t *USBD_FS_ManufacturerStr(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    USBD_GetString((uint8_t *)USBD_MANUFACTURER_STRING, hStrDesc, length);
    return hStrDesc;
}
static uint8_t *USBD_FS_ProductStr(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    USBD_GetString((uint8_t *)USBD_PRODUCT_STRING_FS, hStrDesc, length);
    return hStrDesc;
}
static uint8_t *USBD_FS_SerialStr(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    *length = USB_SIZ_STRING_SERIAL;
    GetSerialNum();
    return hSerialStr;
}
static uint8_t *USBD_FS_ConfigStr(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    USBD_GetString((uint8_t *)USBD_CONFIGURATION_STRING, hStrDesc, length);
    return hStrDesc;
}
static uint8_t *USBD_FS_InterfaceStr(USBD_SpeedTypeDef speed, uint16_t *length)
{
    UNUSED(speed);
    USBD_GetString((uint8_t *)USBD_INTERFACE_STRING, hStrDesc, length);
    return hStrDesc;
}
