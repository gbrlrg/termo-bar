// Funções privadas do IOKit para ler eventos de temperatura dos sensores HID
// do Apple Silicon. As demais (cliente, serviços, propriedades) são públicas.
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>

typedef struct CF_BRIDGED_TYPE(id) __IOHIDEvent *IOHIDEventRef;

IOHIDEventRef _Nullable IOHIDServiceClientCopyEvent(IOHIDServiceClientRef _Nonnull service, int64_t type, int32_t options, int64_t timestamp) CF_RETURNS_RETAINED;
double IOHIDEventGetFloatValue(IOHIDEventRef _Nonnull event, int32_t field);

// O cliente "simple" público não expõe os sensores de temperatura; o completo sim.
IOHIDEventSystemClientRef _Nonnull IOHIDEventSystemClientCreate(CFAllocatorRef _Nullable allocator) CF_RETURNS_RETAINED;
int32_t IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef _Nonnull client, CFDictionaryRef _Nonnull matching);

// Energia por processo (proc_pid_rusage) e o app "responsável" por cada processo,
// o mesmo agrupamento que o Monitor de Atividade usa.
#include <libproc.h>
#include <sys/resource.h>
pid_t responsibility_get_pid_responsible_for_pid(pid_t pid);

// IOReport (libIOReport): energia total da GPU. No macOS 27, sem root, só o canal
// "GPU Energy" do grupo "Energy Model" vem preenchido (CPU/ANE zerados).
typedef struct __IOReportSubscription *IOReportSubscriptionRef;
CFDictionaryRef _Nullable IOReportCopyChannelsInGroup(CFStringRef _Nullable group, CFStringRef _Nullable subgroup, uint64_t a, uint64_t b, uint64_t c) CF_RETURNS_RETAINED;
IOReportSubscriptionRef _Nullable IOReportCreateSubscription(void * _Nullable a, CFMutableDictionaryRef _Nonnull channels, CFMutableDictionaryRef _Nullable * _Nonnull subscribed, uint64_t b, CFTypeRef _Nullable c);
CFDictionaryRef _Nullable IOReportCreateSamples(IOReportSubscriptionRef _Nonnull subscription, CFMutableDictionaryRef _Nonnull channels, CFTypeRef _Nullable a) CF_RETURNS_RETAINED;
CFDictionaryRef _Nullable IOReportCreateSamplesDelta(CFDictionaryRef _Nonnull previous, CFDictionaryRef _Nonnull current, CFTypeRef _Nullable a) CF_RETURNS_RETAINED;
CFStringRef _Nullable IOReportChannelGetChannelName(CFDictionaryRef _Nonnull channel);
CFStringRef _Nullable IOReportChannelGetUnitLabel(CFDictionaryRef _Nonnull channel);
int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef _Nonnull channel, int32_t index);

// Pressão térmica do kernel (0 nominal, 1 moderada, 2 pesada, 3 crítica, 4 suspensão).
#include <notify.h>

// SMC (AppleSMC): rotação das ventoinhas, legível sem root. A estrutura é a do user client
// do kernel e precisa do layout do C; declarada em Swift, o preenchimento sairia diferente.
typedef struct {
    uint8_t major, minor, build, reserved;
    uint16_t release;
} SMCVersion;
typedef struct {
    uint16_t version, length;
    uint32_t cpuPLimit, gpuPLimit, memPLimit;
} SMCPLimitData;
typedef struct {
    uint32_t dataSize, dataType;
    uint8_t dataAttributes;
} SMCKeyInfo;
typedef struct {
    uint32_t key;
    SMCVersion version;
    SMCPLimitData pLimitData;
    SMCKeyInfo keyInfo;
    uint8_t result, status, data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData;
