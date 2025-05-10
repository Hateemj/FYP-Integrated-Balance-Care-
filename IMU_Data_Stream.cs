using UnityEngine;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public class SensorReceiver : MonoBehaviour
{
    public int listenPort = 8051;
    UdpClient udpClient;
    Thread receiveThread;

    private Quaternion sensorRotation = Quaternion.identity;
    private Vector3 rawFreeAcceleration = Vector3.zero;
    private volatile bool newDataAvailable = false;

    // Expose current rotation for other scripts
    public Quaternion CurrentRotation
    {
        get { return sensorRotation; }
    }

    void Start()
    {
        udpClient = new UdpClient(listenPort);
        receiveThread = new Thread(ReceiveData);
        receiveThread.IsBackground = true;
        receiveThread.Start();
        Debug.Log("UDP Receiver started on port " + listenPort);
    }

    void ReceiveData()
    {
        IPEndPoint anyIP = new IPEndPoint(IPAddress.Any, listenPort);
        while (true)
        {
            try
            {
                byte[] data = udpClient.Receive(ref anyIP);
                string dataStr = Encoding.ASCII.GetString(data);
                string[] tokens = dataStr.Split(',');
                if (tokens.Length >= 8)
                {
                    float qW = float.Parse(tokens[1]);
                    float qX = float.Parse(tokens[2]);
                    float qY = float.Parse(tokens[3]);
                    float qZ = float.Parse(tokens[4]);

                    sensorRotation = ConvertIMUToUnityQuaternion(qX, qY, qZ, qW);

                    float faX = float.Parse(tokens[5]);
                    float faY = float.Parse(tokens[6]);
                    float faZ = float.Parse(tokens[7]);
                    rawFreeAcceleration = new Vector3(faX, faY, faZ);

                    newDataAvailable = true;
                }
            }
            catch (System.Exception e)
            {
                Debug.Log("Error receiving data: " + e.Message);
            }
        }
    }

    void Update()
    {
        if (!newDataAvailable)
            return;

        newDataAvailable = false;

        // Apply rotation to this GameObject
        transform.rotation = sensorRotation;


    }

    void OnApplicationQuit()
    {
        if (receiveThread != null)
            receiveThread.Abort();
        if (udpClient != null)
            udpClient.Close();
    }

    Quaternion ConvertIMUToUnityQuaternion(float qX, float qY, float qZ, float qW)
    {
        // Movella DOT: NED (X = North, Y = East, Z = Down)
        // Unity:       X = right, Y = up, Z = forward
        // Mapping:     X -> -Z, Y -> X, Z -> -Y
        return new Quaternion(qY, -qZ, -qX, qW);
    }
}
