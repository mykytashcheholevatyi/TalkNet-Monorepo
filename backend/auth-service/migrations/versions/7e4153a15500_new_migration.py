from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '15e7949b91c2'
down_revision = '7e4153a15500'
branch_labels = None
depends_on = None


def upgrade():
    # Обновление базы данных: добавление столбцов и ограничений
    op.add_column('user', sa.Column('email', sa.String(100), unique=True, nullable=False))
    op.add_column('user', sa.Column('password', sa.String(80), nullable=False))
    # Добавление уникального ограничения с явным именем
    op.create_unique_constraint('unique_user_email', 'user', ['email'])


def downgrade():
    # Откат изменений базы данных
    op.drop_constraint('unique_user_email', 'user', type_='unique')
    op.drop_column('user', 'password')
    op.drop_column('user', 'email')
