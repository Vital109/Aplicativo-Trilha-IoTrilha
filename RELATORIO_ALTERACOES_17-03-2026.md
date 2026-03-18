# Relatório de Alterações — 17/03/2026

### Resumo
**5 arquivos modificados, 1 arquivo criado** | +289 linhas adicionadas, -50 removidas

---

### 1. `api_server.py` — Backend Flask

**2 novos endpoints adicionados:**

- **ENDPOINT 25** — `GET /api/usuario/buscar-cpf/<cpf>`
  Busca um usuário no banco pelo CPF. Retorna id, nome, email, tipo_perfil, telefone e foto.

- **ENDPOINT 26** — `PUT /api/usuario/<id>/perfil`
  Atualiza o `tipo_perfil` de um usuário (1=Trilheiro, 2=Guia, 3=Operador).

> **Atenção:** Este arquivo precisa ser copiado para o servidor remoto (`200.19.144.16`) e o Flask reiniciado para os endpoints funcionarem.

#### O que deve ser adicionado no `api_server.py`

Inserir o bloco abaixo **antes da linha `if __name__ == '__main__':`**:

```python
# --- ENDPOINT 25: Buscar Usuário por CPF ---
@app.route('/api/usuario/buscar-cpf/<string:cpf>', methods=['GET'])
def buscar_usuario_por_cpf(cpf):
    cpf_limpo = ''.join(filter(str.isdigit, cpf))
    if len(cpf_limpo) != 11:
        return jsonify({"erro": "CPF inválido"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                "SELECT id, nome, email, tipo_perfil, telefone, url_foto_perfil FROM usuarios WHERE cpf = %s",
                (cpf_limpo,)
            )
            usuario = cursor.fetchone()
            if not usuario:
                return jsonify({"erro": "Usuário não encontrado"}), 404
            return jsonify(usuario)
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 26: Atualizar Tipo de Perfil do Usuário ---
@app.route('/api/usuario/<int:user_id>/perfil', methods=['PUT'])
def atualizar_perfil_usuario(user_id):
    data = request.json
    novo_tipo = data.get('tipo_perfil')

    if novo_tipo not in [1, 2, 3]:
        return jsonify({"erro": "tipo_perfil inválido. Use 1 (Trilheiro), 2 (Guia) ou 3 (Operador)"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                "UPDATE usuarios SET tipo_perfil = %s WHERE id = %s",
                (novo_tipo, user_id)
            )
            conexao.commit()
            if cursor.rowcount == 0:
                return jsonify({"erro": "Usuário não encontrado"}), 404
            return jsonify({"mensagem": "Perfil atualizado com sucesso!"})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()
```

---

### 2. `register_screen.dart` — Tela de Cadastro

**Lógica removida:**
- Removido o dropdown de escolha de tipo de perfil (Trilheiro/Guia/Operador)
- Removido o campo de código de administrador
- Removido campo de idade manual

**Lógica adicionada:**
- Cadastro agora é fixo como **Trilheiro** (`tipoPerfil = 1`)
- Campo de idade substituído por **seletor de data de nascimento** (calcula a idade automaticamente)
- Validação completa de CPF com verificação dos dígitos verificadores

---

### 3. `assign_role_screen.dart` — Nova Tela *(arquivo novo)*

Tela exclusiva para operadores de base promoverem usuários. Fluxo:
1. Operador digita o CPF de um usuário
2. App busca e exibe os dados da conta
3. Operador seleciona a nova função (Guia ou Operador de Base)
4. Confirma a atribuição

---

### 4. `operator_screen.dart` — Tela Principal do Operador

- Adicionado card de acesso rápido **"Atribuir Função a Usuário"** na tela principal

---

### 5. `operator_drawer.dart` — Menu Lateral do Operador

- Adicionado item **"Atribuir Função a Usuário"** no drawer, com navegação para a nova tela

---

### 6. `api_service.dart` — Serviço de API (Flutter)

2 novos métodos adicionados:
- `buscarUsuarioPorCpf(String cpf)` — chama o endpoint 25
- `atualizarPerfilUsuario(int userId, int tipoPerfil)` — chama o endpoint 26

Ambos com tratamento de erro para respostas HTML (servidor desatualizado) e timeouts.
