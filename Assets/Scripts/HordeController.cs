using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class HordeController : MonoBehaviour
{
    [SerializeField] private GameObject hordeContainer;
    [SerializeField] private GameObject enemy;
    [SerializeField] private TMP_Text prepareText;
    [SerializeField] private List<Transform> possibleSpawnPositions;

    private int hordeNumber = 1;

    [Header("Settings")]
    [SerializeField] private int firstHordeEnemyAmount = 16;
    [SerializeField] private int secondHordeEnemyAmount = 24;
    [SerializeField] private int thirdHordeEnemyAmount = 32;



    [Header("UI")]
    [SerializeField] private GameObject hordePanel;
    [SerializeField] private TMP_Text hordeText;
    [SerializeField] private TMP_Text hordeTimeText;

    float currentHordeTime;

    bool hordesEnabled = false;

    Dictionary<int, int> hordeEnemyAmountStat = new Dictionary<int, int>();


    void Awake()
    {
        hordeEnemyAmountStat.Add(1, firstHordeEnemyAmount);
        hordeEnemyAmountStat.Add(2, secondHordeEnemyAmount);
        hordeEnemyAmountStat.Add(3, thirdHordeEnemyAmount);
    }

    void OnEnable()
    {
        GameEvents.OnShipUpgraded += NextHorde;
    }

    void OnDisable()
    {
        GameEvents.OnHorderDefeated -= NextHorde;
    }

    void Start()
    {
        StartCoroutine(WaitAndStartHorde());
    }

    void Update()
    {
        if (hordesEnabled == false) return;

        currentHordeTime += Time.deltaTime;
        hordeTimeText.text = "Tempo: " + Mathf.Round(currentHordeTime).ToString() + "s";

        if (hordeContainer.transform.childCount == 0 && currentHordeTime > 3)
        {
            hordesEnabled = false;

            hordePanel.SetActive(false);
            currentHordeTime = 0;

            hordeNumber++;

            if (hordeNumber < 4)
            {
                GameEvents.OnHorderDefeated.Invoke();
            }
            else
            {
                GameEvents.OnAllHordesDefeated.Invoke();
            }
        }
    }

    void NextHorde()
    {
        if (hordeNumber > 3) return;
        StartCoroutine(WaitAndStartHorde());
    }

    void StartHorde()
    {
        hordeText.text = "Horda " + hordeNumber + " / 3";

        hordePanel.SetActive(true);
        prepareText.gameObject.SetActive(false);
        hordesEnabled = true;

        StartCoroutine(SpawnEnemy(hordeNumber));
    }

    IEnumerator SpawnEnemy(int horde)
    {
        for (int i = 0; i < hordeEnemyAmountStat[horde] - 1; i++)
        {
            yield return new WaitForSeconds(1.2f);
            int randomChoice = Random.Range(0, possibleSpawnPositions.Count);
            Instantiate(enemy, possibleSpawnPositions[randomChoice].position, Quaternion.identity, hordeContainer.transform);
        }
    }

    IEnumerator WaitAndStartHorde()
    {
        prepareText.gameObject.SetActive(true);
        yield return new WaitForSeconds(3.0f);
        StartHorde();
    }
}
