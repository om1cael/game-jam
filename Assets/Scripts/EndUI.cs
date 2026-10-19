using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class EndUI : MonoBehaviour
{
    public GameObject restartPanel;
    public Button restartButton;

    void OnEnable()
    {
        GameEvents.OnAllHordesDefeated += ShowRestartUI;
        GameEvents.OnPlayerDie += ShowRestartUI;
    }

    void OnDisable()
    {
        GameEvents.OnAllHordesDefeated -= ShowRestartUI;
        GameEvents.OnPlayerDie -= ShowRestartUI;
    }

    void ShowRestartUI()
    {
        restartPanel.SetActive(true);

        restartButton.onClick.AddListener(() =>
        {
            SceneManager.LoadScene(0);
            restartButton.onClick.RemoveAllListeners();
        });
    }
}
