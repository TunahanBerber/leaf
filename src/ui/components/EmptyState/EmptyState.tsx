import { BookIcon } from "../../icons/BookIcon";
import "./EmptyState.css";

export const EmptyState = () => {
    return (
        <div className="empty-state">
            <div className="empty-state__icon">
                <BookIcon />
            </div>
            <h2 className="empty-state__title">Kitaplığınız şu anda boş</h2>
            <p className="empty-state__description">
                Kitaplığınız boş — ve bu da iyi. İlk kitabınızı ekleyerek onu oluşturun.
            </p>
            <button className="empty-state__action">
                Kitap Ekle
            </button>
        </div>
    );
};
