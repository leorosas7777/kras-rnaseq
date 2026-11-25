# =====================================================================
# 1. ROL DE INSTANCIA: lo usan las máquinas EC2 de Batch
# =====================================================================

# Quién puede usarlo: el servicio EC2
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]          # pista: ec2.amazonaws.com
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${var.project}-ecs-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Permisos ya hechos por AWS para máquinas de contenedores
resource "aws_iam_role_policy_attachment" "ecs_instance_base" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# EC2 no usa roles directamente: necesita un "instance profile" que lo envuelva
resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.project}-ecs-instance"
  role = aws_iam_role.ecs_instance.name         # pista: el nombre del rol de arriba
}

# =====================================================================
# 2. ROL DEL JOB: lo usan los contenedores de nf-core
# =====================================================================

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]          # pista: ecs-tasks.amazonaws.com
    }
  }
}

resource "aws_iam_role" "batch_job" {
  name               = "${var.project}-batch-job"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json            # pista: igual que arriba, con el otro data
}

# =====================================================================
# 3. PERMISO DE S3: solo TU bucket (privilegio mínimo)
# =====================================================================

data "aws_iam_policy_document" "s3_access" {
  # Listar el contenido del bucket
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.main.arn]
  }
  # Leer, escribir y borrar archivos DENTRO del bucket
  statement {
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:GetObjectTagging", "s3:PutObjectTagging",
      "s3:AbortMultipartUpload"
    ]
    resources = ["${aws_s3_bucket.main.arn}/*"]   # el /* = "todo lo de adentro"
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "${var.project}-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
}

# Se lo damos a los dos gafetes
resource "aws_iam_role_policy_attachment" "job_s3" {
  role       = aws_iam_role.batch_job.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy_attachment" "instance_s3" {
  role       = aws_iam_role.ecs_instance.name 
  policy_arn = aws_iam_policy.s3_access.arn
}
