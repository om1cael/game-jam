using System.Collections.Generic;
using UnityEngine;

public class ShipController : MonoBehaviour
{
    [SerializeField] private GameObject eInteractionKey;
    [SerializeField] private List<Sprite> shipEvolutions; // there are 3 idxs starting from 0
    private SpriteRenderer spriteRenderer;

    private int currentShipEvolution = 0;

    private bool fixAllowed = false;

    bool ePressed = false;


    private InputSystem_Actions inputActions;

    void Awake()
    {
        inputActions = new InputSystem_Actions();
    }


    void Start()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
    }

    void OnEnable()
    {
        GameEvents.OnHorderDefeated += AllowFix;
    }

    void OnDisable()
    {
        GameEvents.OnHorderDefeated -= AllowFix;
    }

    void AllowFix()
    {
        eInteractionKey.SetActive(true);
        fixAllowed = true;

    }

    void Update()
    {
        ePressed = Input.GetKeyDown(KeyCode.E);
    }

    void OnTriggerStay2D(Collider2D collision)
    {
        if (collision.gameObject.CompareTag("Player") && fixAllowed && ePressed)
        {
            Debug.Log("here");
            currentShipEvolution++;
            spriteRenderer.sprite = shipEvolutions[currentShipEvolution];

            eInteractionKey.SetActive(false);
            fixAllowed = false;

            GameEvents.OnShipUpgraded.Invoke();
        }
    }
}