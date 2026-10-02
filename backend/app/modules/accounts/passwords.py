"""Senhas recusadas por serem as primeiras que um invasor tenta.

A recomendação atual (NIST SP 800-63B) é não impor regras de composição
(maiúscula, símbolo...) e, em vez disso, recusar senhas muito comuns ou óbvias.
A lista é curta de propósito: as campeãs das listas de senhas vazadas que têm o
tamanho mínimo aceito, as equivalentes brasileiras e as que citam o produto.

Isso não substitui o limite de tentativas de login; os dois se somam.
"""

COMMON_PASSWORD_MESSAGE = "Esta senha é muito comum. Escolha outra."  # noqa: S105

COMMON_PASSWORDS = frozenset(
    {
        # Sequências e repetições de teclado
        "12345678", "123456789", "1234567890", "12345678910", "0123456789",
        "123123123", "12341234", "87654321", "987654321", "1q2w3e4r", "1q2w3e4r5t",
        "1qaz2wsx", "qwertyui", "qwertyuiop", "qwerty123", "qwerty1234", "asdfghjk",
        "asdfghjkl", "zxcvbnm123", "abcdefgh", "abcd1234", "abc12345", "a1b2c3d4",
        # As mais comuns em inglês
        "password", "password1", "password12", "password123", "passw0rd", "p@ssw0rd",
        "iloveyou", "sunshine", "princess", "football", "baseball", "superman",
        "trustno1", "welcome1", "welcome123", "admin123", "admin1234",
        "administrator", "letmein123", "changeme",
        # As mais comuns no Brasil
        "senha123", "senha1234", "senha12345", "minhasenha", "mudar123", "trocar123",
        "brasil123", "flamengo", "flamengo123", "corinthians", "palmeiras",
        "saopaulo", "vascodagama", "euteamo123", "teamoamor", "felicidade",
        # O próprio produto
        "yvenist1", "yvenist123", "yvenist1234",
    }
)  # fmt: skip


def is_too_common(password: str) -> bool:
    """A senha está entre as mais usadas, ou é um único caractere repetido?"""
    normalized = password.strip().casefold()
    return normalized in COMMON_PASSWORDS or len(set(normalized)) == 1
