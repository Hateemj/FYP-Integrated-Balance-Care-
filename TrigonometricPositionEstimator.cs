using UnityEngine;

public class TrigonometricPositionEstimator : MonoBehaviour
{
    [Header("References")]
    public SensorReceiver imuReceiver;   // provides CurrentRotation
    public Transform headAnchor;    // headset reference

    [Header("Anatomy & Limits")]
    [Tooltip("Vertical drop from head to lumbar (m)")]
    public float headsetToLumbarDistance = 1.0313f;
    [Tooltip("Max horizontal sway radius (m)")]
    public float maxSwayDistance = 1.0f;

    [Header("Sensor Mounting")]
    [Tooltip("Roll offset so side-mounted sensor zeros out.\n" +
             "Use -90 or +90 depending on which side.")]
    public float rollOffsetDeg = -90f;

    // internal calibration
    private Quaternion neutralPitchRoll;
    private float neutralYaw;
    private bool initialized;

    void Start()
    {
        // nothing—calibration happens on first Update
    }

    void Update()
    {
        if (imuReceiver == null || headAnchor == null) return;

        // 1️⃣ Read sensor rotation and apply fixed roll offset
        Quaternion raw = imuReceiver.CurrentRotation;
        if (Mathf.Abs(rollOffsetDeg) > 0.1f)
            raw = raw * Quaternion.Euler(0f, 0f, rollOffsetDeg);

        // 2️⃣ On first frame, lock in neutral pitch/roll and yaw
        if (!initialized)
        {
            // neutralPitchRoll: drop yaw so we only remove pitch+roll offsets
            Vector3 e = raw.eulerAngles;
            e.x = (e.x > 180f) ? e.x - 360f : e.x;
            e.z = (e.z > 180f) ? e.z - 360f : e.z;
            neutralPitchRoll = Quaternion.Euler(e.x, 0f, e.z);

            // neutralYaw: full yaw to rotate local sway into world
            neutralYaw = raw.eulerAngles.y;
            initialized = true;
        }

        // 3️⃣ Extract pitch+roll relative to neutral
        Quaternion prRelative = Quaternion.Inverse(neutralPitchRoll) * raw;
        Vector3 prEuler = prRelative.eulerAngles;
        float pitchDeg = (prEuler.x > 180f) ? prEuler.x - 360f : prEuler.x;
        float rollDeg = (prEuler.z > 180f) ? prEuler.z - 360f : prEuler.z;

        // 4️⃣ Compute local sway: tan(tilt)*distance
        float ap = Mathf.Tan(Mathf.Deg2Rad * pitchDeg) * headsetToLumbarDistance; // Z
        float ml = Mathf.Tan(Mathf.Deg2Rad * rollDeg) * headsetToLumbarDistance; // X
        Vector3 localSway = new Vector3(ml, 0f, ap);

        // 5️⃣ Get current yaw relative to neutral
        float currentYaw = Mathf.DeltaAngle(neutralYaw, raw.eulerAngles.y);

        // 6️⃣ Rotate local sway into world by yaw
        Vector3 worldSway = Quaternion.Euler(0f, currentYaw, 0f) * localSway;

        // 7️⃣ Clamp horizontal radius
        //if (worldSway.magnitude > maxSwayDistance)
        //    worldSway = worldSway.normalized * maxSwayDistance;

        // 8️⃣ Final position under headAnchor
        Vector3 finalPos = headAnchor.position +
                           new Vector3(worldSway.x,
                                       -headsetToLumbarDistance,
                                       worldSway.z);

        transform.position = finalPos;

        // Optional debug:
        Debug.DrawLine(headAnchor.position, finalPos, Color.cyan);
    }
}
