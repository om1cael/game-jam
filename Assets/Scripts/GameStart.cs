using UnityEngine;

public class GameStart : MonoBehaviour
{
    public AudioClip gameplayAudio;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        AudioManager.Instance.PlayMusic(gameplayAudio);
    }

    // Update is called once per frame
    void Update()
    {

    }
}
