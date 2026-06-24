#ifndef AXIS_H
#define AXIS_H

#include <stdint.h>
#include <stdbool.h>
#include "motor.h"
#include "speed_pi.h"
#include "position_p.h"
#include "encoder.h"
#include "cmd_parser.h"   /* CmdMode_t */

/* ============================================================================
 * Eksen demeti (Aşama 3.3 — instance-based MIMO altyapısı)
 *
 * Her eksen = motor kanalı + enkoder + hız PI + pozisyon P + MA filtresi +
 * mod + mirror durumu. Aşama-2'nin kanıtlı cascade'i her eksene bağımsız
 * uygulanır (baseline-önce yöntem, ROADMAP §3); kuplaj 3.4-3.5'te ölçülür.
 *
 *   g_axis[0] — motor-1 ekseni (Motor1, enc-1 TIM2 PA15/PB3)
 *               ⚠ mevcut fiziksel ünite CW-kusurlu (memory/ROADMAP);
 *               redüktörsüz yedek motor gelince yalnız ünite değişir,
 *               firmware/kablolama aynı kalır.
 *   g_axis[1] — motor-2 ekseni (Motor2, enc-2 TIM1 PA8/PA9)
 *               = Aşama 1-2'de karakterize SAĞLIKLI ünite (K=53.89, τ=60.5 ms)
 *               → Aşama-2 kazançları bu eksende doğrudan geçerli.
 *
 * Komut eşlemesi (cmd_parser): temel ad → eksen-0; '2' sonekli → eksen-1
 * (MODE2:, SP_W2:, POS_DEG2:, KPP2:, KP2:, KI2:, SLEW2:, DUTY2:).
 * ============================================================================ */

typedef struct {
    MotorCh_t    *motor;            /* &Motor1 / &Motor2 */
    SpeedPI_t     spi;              /* hız iç döngü PI (Aşama 2.2/2.3) */
    PositionP_t   ppos;             /* pozisyon dış döngü P (Aşama 2.5) */
    SpeedFilter_t filt;             /* hız MA penceresi (Aşama 2.3) */

    int32_t     (*enc_count)(void); /* Encoder_GetCount / Encoder2_GetCount */
    void        (*enc_reset)(void); /* Encoder_Reset / Encoder2_Reset */
    float       (*enc_speed)(float dt); /* ham motor şaftı rad/s */

    CmdMode_t     mode;             /* eksenin aktif modu (cmd_parser set eder) */

    /* MIRROR (Aşama 2.7) durumu — eksen-bazlı: her eksen IMU hedefini
     * bağımsız takip edebilir (bugün ikisi de fused_pitch; Aşama 5'te
     * pitch/roll eşlemesi yapılır). */
    float mirror_pitch0;            /* göreli referans (geçiş anı pitch) */
    float mirror_ref;               /* slew sonrası uygulanan θ_ref (derece) */
    bool  mirror_prev;              /* MIRROR'a yeni giriş edge-detect */

    /* STAB polaritesi (Aşama 5 yüklü) — target = stab_dir·rel (YALNIZ STAB).
     * Montaj kinematik işaretinden: stab_dir = −sign(k_kin). Firmware-default −1
     * (target=−rel; yüksüz K0 STAB böyle valide edildi). Yüklü LP k_kin=−1.04
     * (Adım-1 ID, archive-loaded-adhoc tag) → stab_dir=+1; STABDIR:/2: ile ayar.
     * ⚠ Yanlış işaret = pozitif feedback = RUNAWAY. */
    float stab_dir;

    /* STAB giriş θ_out ofseti (Aşama 5) — STAB target = stab_theta0 + stab_dir·rel.
     * STAB girişinde o anki çıkış-mili açısı yakalanır → kontrolcü GİRİŞ pozisyonunu
     * tutar (önceki tasarım sıfır-referanslıydı → off-hanging tutamıyordu, hep asılı
     * pozisyona düşüyordu). MIRROR ve θ_out=0'da giren yüksüz STAB için 0 (geri-uyumlu). */
    float stab_theta0;

    /* Gyro feedforward (K2, Aşama 3.8) — YALNIZ STAB; 2-DOF base-bozucu reddi.
     * ω_ff = k_ff·LPF(gy)·DEG2RAD motor-mili hız-setpoint'ine eklenir → yavaş dış
     * pozisyon-döngüsünü baypas eder (reddi-bant ~4×, matlab design_gyro_feedforward).
     * FF dışsal sinyal (gyro) → kapalı-döngü kararlılığını etkilemez. Kaynak:
     * [Franklin2010] §7.3 (2-DOF feedforward), [Hilkert2008] (gimbal inertial-rate FF). */
    float k_ff;                     /* FF kazancı = redüktör 9.7 (analitik); KFF2: ile ayar */
    bool  gyro_ff_en;               /* GÜVENLİK: default KAPALI; KFF2:<≠0> açar, KFF2:0 kapar */
    float gy_ff_lpf;                /* gyro LPF durumu (FF girişi HF gürültü süzme, ~12 Hz) */

    /* Sürtünme+gravite feedforward (yüklü, computed-torque) — cascade modları (POS/MIRROR/STAB).
     * Bilinen bozucuyu plant-girişine (DUTY) enjekte eder → PI sürtünmeyi yenmek için
     * integral biriktirmez → stick-slip limit-cycle bastırılır:
     *   u_ff = kff_grav·sin(θ_out) + uc·tanh(ω_ref/coul_db)   (uc=ω_ref≥0?kff_coul:kff_coul_rev — pürüzsüz+yön-bağımlı, §12.13.4-5)
     * θ_out=çıkış mili açısı (RESET=dip=0). Gyro-FF'ten FARKLI enjeksiyon noktası: bu
     * bozucu duty-domeninde (gravite/Coulomb duty olarak ölçüldü) → duty'ye, ω_ref'e değil.
     * Ölçüm: artifacts/3/loaded_id_m2/20260613_loaded_id_run1 (a=0.097, u_c=0.090, u_s=0.107).
     * Tasarım/sim: matlab/asama_3_mimo_model/design_loaded_feedforward.m (sign sim-ideal,
     * ölü-bant chatter-safe). [Franklin2010] §7.5, [Olsson1998] §6. GÜVENLİK: default KAPALI. */
    float kff_grav;                 /* gravite FF kazancı = a=mgL/K (ölçülen 0.097); LFFG: ile ayar */
    float kff_coul;                 /* Coulomb FF u_c FORWARD (HP rijit §12.13.5: 0.14); LFFC: ile ayar */
    float kff_coul_rev;             /* Coulomb FF u_c REVERSE — sürtünme YÖN-ASİMETRİK (HP: 0.20 vs fwd 0.14, §12.13.5) */
    float coul_db;                  /* Coulomb ölü-bantı = tanh geçiş ε'si (|ω_ref| ölçeği rad/s) — setpoint chatter koruması */
    bool  load_ff_en;               /* GÜVENLİK: default KAPALI; LFF:<≠0> açar, LFF:0 kapar */
} Axis_t;

#define AXIS_COUNT 2
extern Axis_t g_axis[AXIS_COUNT];   /* main.c'de tanımlı */

#endif /* AXIS_H */
